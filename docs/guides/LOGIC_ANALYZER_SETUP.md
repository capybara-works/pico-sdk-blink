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

ファームウェアはI2Cスキャンを出力し、WokwiではGP4/GP5に仮想SSD1306 OLEDを接続します。
ただし、現在の実機最小配線ではI2C信号をロジックアナライザに接続していません。
実機でI2Cを観測する前に、追加で以下を配線してください。

| ロジックアナライザ | Pico |
|---|---|
| D0 | GP5 / SCL |
| D1 | GP4 / SDA |

現在のBlink実機確認だけなら、まずD2だけを Pico Pin 1 / GP0 / UART0 TX に接続して
UARTを観測します。

## 取得と保存

```bash
PICO_LOGIC_UART=1 scripts/capture_logic_uart.sh 3000  # UART TXを3000ms取得
PICO_LOGIC_I2C=1 scripts/capture_logic_i2c.sh 1000    # I2Cを1000ms取得
```

UART実測では `LED on` と `LED off` の両方がデコードされた場合に `pass` になります。
現在の最小配線(GND + D2→GP0)では、まず `capture_logic_uart.sh` を単独実行してください。
`scripts/verify_all.sh` に組み込む場合も、I2C未配線なら `PICO_LOGIC_UART=1`
だけを指定します。`PICO_LOGIC_ANALYZER=1` はUARTとI2Cの両方を実測する互換スイッチなので、
I2C未配線の状態ではI2C側が `fail` になります。

`PICO_LOGIC_I2C=1` を付けた実測では、I2Cデコード注釈が1件も得られない場合は
`fail` になります。端子未接続、SCL/SDAの取り違え、pull-up不足、対象ファームウェアが
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
