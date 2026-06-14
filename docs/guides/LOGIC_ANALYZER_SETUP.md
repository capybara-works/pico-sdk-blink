# ロジックアナライザセットアップ (Logic Analyzer Setup)

FX2LP系USBロジックアナライザ(8ch / 24MHz クラス、
いわゆる "Saleae互換" 中華クローン)を sigrok / PulseView で使い、
Picoの通信を物理層から観測します。

現状、`scripts/capture_logic_i2c.sh` は sigrok-cli 未インストール環境では
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

## 配線(I2C観測の例)

`config/hardware.example.yaml` の `logic_analyzer.channels` に対応:

| チャネル | 信号 |
|---|---|
| D0 | SCL |
| D1 | SDA |
| D2 | UART TX (GP0) |
| D3 | UART RX (GP1) |
| GND | Pico GND (必須) |

## 取得と保存

```bash
PICO_LOGIC_ANALYZER=1 scripts/capture_logic_i2c.sh 1000   # 1000ms取得 (実測の明示的有効化が必要)
```

`PICO_LOGIC_ANALYZER=1` を付けた実測では、I2Cデコード注釈が1件も得られない場合は
`fail` になります。端子未接続、SCL/SDAの取り違え、pull-up不足、対象ファームウェアが
I2Cを出していない状態を、成功として扱わないためです。

出力:

- `evidence/latest/logic_i2c_decode.txt` — I2Cデコード結果(Start/アドレス/ACK・NACK/データ/Stop)
- `evidence/latest/logic_i2c_result.json` — 機械可読な結果

**取得結果は必ずCSVまたはテキストに変換して保存し、AIに読ませます。**
波形画像のスクリーンショットだけでは機械判定できないため、証拠の主体は
テキストデコード結果とします(画像は補助)。デコード結果の読み方の例は
`evidence/samples/i2c_nack_decode_sample.txt` を参照してください。
