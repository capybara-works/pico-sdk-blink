# ロジックアナライザセットアップ (Logic Analyzer Setup)

FX2LP系USBロジックアナライザ(8ch / 24MHz クラス、
いわゆる "Saleae互換" 中華クローン)を sigrok / PulseView で使い、
Picoの通信を物理層から観測します。

現状、`scripts/capture_logic_uart.sh` / `scripts/capture_logic_i2c.sh` は sigrok-cli 未インストール環境では
サンプルデコード結果を返す**スタブ**です。

## 対象と限界

- **最初の対象は UART / I2C / SPI の低速通信**(数kHz〜数百kHz)。
  24MHzサンプリングのFX2LP系で十分観測できる帯域に限定します。
- **ロジックアナライザはオシロスコープではない。**
  取得できるのはデジタル(H/L)のタイミングのみ。
  **アナログ波形、電圧レベル、ノイズ、リンギングの厳密測定には使えない。**
  信号品質の問題が疑われる場合はオシロスコープが必要です。

## ツール

```bash
# macOS
brew install sigrok-cli
# GUIで波形を見る場合
brew install --cask pulseview

# Linux
sudo apt install sigrok-cli pulseview
```

FX2LP系デバイスは sigrok の `fx2lafw` ドライバで動作します(初回接続時に
ファームウェアが自動ロードされます)。

接続確認:

```bash
sigrok-cli --driver fx2lafw --scan
# 例: fx2lafw:conn=20.3 - sigrok FX2 LA (8ch) [S/N: sigrok FX2 8ch]
```

複数デバイスがある場合や自動検出が不安定な場合は、`config/hardware.local.yaml`
の `logic_analyzer.conn` に `20.3` のような `conn` 値を記録します。
USBの抜き差しや接続ポート変更で `conn` 値が変わることがあるため、
`No devices found` になった場合は再度 `sigrok-cli --driver fx2lafw --scan` を実行し、
ローカル設定を更新してください。

## 配線

### UART観測(最初の確認)

既存ファームウェアはPico UART0 TX (GP0) に `LED on` / `LED off` を出力します。
Debug ProbeのUART配線は外さず、ロジックアナライザを同じ信号線へ並列接続します。

| ロジックアナライザ | Pico |
|---|---|
| GND | Pin 3 / GND |
| D2 | Pin 1 / GP0 / UART0 TX |

### 既定チャネル割り当て

`config/hardware.example.yaml` の `logic_analyzer.channels` に対応:

| チャネル | 信号 |
|---|---|
| D0 | SCL |
| D1 | SDA |
| D2 | UART TX (GP0) |
| D3 | UART RX (GP1) |
| GND | Pico GND (必須) |

ファームウェアはI2Cスキャンを出力し、GP4/GP5にSSD1306 OLEDを接続します。
実機でI2Cを観測する場合は、OLEDと同じ信号線へ並列に以下を接続します
(ロジアナは高インピーダンスなのでOLEDと同居して問題ありません)。

| ロジックアナライザ | Pico |
|---|---|
| D0 | GP5 / SCL |
| D1 | GP4 / SDA |

確認済みの実測構成は GND + D2→GP0 + D0→GP5 + D1→GP4 で、`PICO_LOGIC_ANALYZER=1` で
`logic_uart` / `logic_i2c` とも pass を確認済み(2026-06-15)。

### 配線診断のコツ(実機ブリングアップで確認済み)

I2Cデコードが `fail`(注釈ゼロ)になった時の切り分け手順。詳細は
[../reports/PHASE2_OLED_LOGIC_BRINGUP_REPORT.md](../reports/PHASE2_OLED_LOGIC_BRINGUP_REPORT.md)。

- **生トグルで各チャネルの活性を見る**(デコード前の一次切り分け):
  ```bash
  PICO_LOGIC_ANALYZER=1 scripts/probe_logic_activity.sh   # 既定6秒
  ```
  各チャネルの `transitions` / `high%` / `ACTIVE|IDLE-HIGH|IDLE-LOW` を表示する診断専用入口
  (pass/fail証拠は出さない)。**SDA(D1)は活発なのに設定上のSCL(D0)がidle-LOWでトグル0**なら、
  ロジックアナライザがそのチャンネルでSCLを見られていない。原因はタップ接触、
  チャンネル割り当て違い、ロジアナ入力不良、またはオフボード側の電気的異常のいずれかなので、
  「配線が抜けた」と即断せず、8ch全体の活動やPico側ログと突き合わせる。
  (素のコマンドで見たい場合は `sigrok-cli --driver fx2lafw --config samplerate=1000000
  --time 6000 --channels D0,D1,D2,D3 -O bits`。)
- **キャプチャ窓は活動間隔を跨ぐ長さにする。** OLED未検出時のI2Cは起動時+約4秒毎の
  スキャンだけなので、1秒キャプチャでは取りこぼす。**≥6秒**で「本当に無信号か」を確定。
- **無通信なら、まずファーム未フラッシュを疑う**(UARTは出るがI2Cは皆無 = 旧ファーム実行中)。
- **`conn` はUSB再列挙で番号が変わる。** FX2が1台だけなら
  `config/hardware.local.yaml` の `logic_analyzer.conn` を空("")にして自動選択にすると安定。

## 取得と保存

```bash
PICO_LOGIC_UART=1 scripts/capture_logic_uart.sh 3000  # UART TXを3000ms取得
PICO_LOGIC_I2C=1 scripts/capture_logic_i2c.sh         # I2Cを取得(既定6000ms)
```

UART実測では `LED on` と `LED off` の両方がデコードされた場合に `pass` になります。
現在の最小配線(GND + D2→GP0)では、まず `capture_logic_uart.sh` を単独実行してください。
`scripts/verify_all.sh` に組み込む場合も、I2C未配線なら `PICO_LOGIC_UART=1`
だけを指定します。`PICO_LOGIC_ANALYZER=1` はUARTとI2Cの両方を実測する互換スイッチなので、
I2C未配線の状態ではI2C側が `fail` になります。

`PICO_LOGIC_I2C=1` を付けた実測では、SSD1306 の期待アドレス `0x3C` が
ACKした場合だけ `pass` になります。デコード注釈が取れていても `0x3C` が
NACKなら `fail` です。端子未接続、SCL/SDAの取り違え、pull-up不足、
OLEDの無給電、モジュール上pull-up/入力保護/コントローラ異常、対象ファームウェアが
I2Cを出していない状態を、成功として扱わないためです。

出力:

- `evidence/latest/logic_uart_decode.txt` — UARTデコード結果(hex byte等)
- `evidence/latest/logic_uart_text.txt` — UARTデコード結果をASCII化したテキスト
- `evidence/latest/logic_uart_result.json` — 機械可読な結果
- `evidence/latest/logic_i2c_decode.txt` — I2Cデコード結果(Start/アドレス/ACK・NACK/データ/Stop)
- `evidence/latest/logic_i2c_result.json` — 機械可読な結果

**取得結果は必ずCSVまたはテキストに変換して保存し、AIに読ませます。**
波形画像のスクリーンショットだけでは機械判定できないため、証拠の主体は
テキストデコード結果とします(画像は補助)。デコード結果の読み方の例は
`evidence/samples/logic_uart_decode_sample.txt` と
`evidence/samples/i2c_nack_decode_sample.txt` を参照してください。
