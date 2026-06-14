# 詳細設計書 (Detailed Design Document)

## 1. ソフトウェア構造
### 1.1 モジュール構成
本ソフトウェアは単一のソースファイル `blink.cpp` で構成される。

*   **blink.cpp**: メインロジック（初期化、メインループ）を含む。

### 1.2 依存ライブラリ
*   **pico_stdlib**: 標準入出力、GPIO制御、時間管理機能を提供。
*   **hardware_i2c**: I2C0を使ったアドレススキャンを提供。

## 2. 処理フロー詳細
### 2.1 メイン関数 (`main`)
プログラムのエントリーポイント。以下の順序で処理を実行する。

1.  **初期化処理**
    *   `stdio_init_all()`: 有効化された標準入出力を初期化する。本プロジェクトではUARTを有効、USB stdioを無効にしている。
    *   `gpio_init(25)`: GP25ピンをGPIOとして初期化する。
    *   `gpio_set_dir(25, GPIO_OUT)`: GP25ピンを出力モードに設定する。
    *   `i2c_init(i2c0, 100000)`: I2C0を100kHzで初期化する。
    *   GP4をSDA、GP5をSCLとして設定し、内部pull-upを有効にする。
    *   I2Cアドレススキャンを実行し、検出したアドレスをUARTへ出力する。

2.  **メインループ (無限ループ)**
    *   **ステップ1: 点灯**
        *   `gpio_put(25, 1)`: GP25にHighを出力し、LEDを点灯させる。
        *   `printf("LED on\n")`: 標準出力に "LED on" を出力する。
    *   **ステップ2: 待機**
        *   `sleep_ms(250)`: 250ミリ秒待機する。
    *   **ステップ3: 消灯**
        *   `gpio_put(25, 0)`: GP25にLowを出力し、LEDを消灯させる。
        *   `printf("LED off\n")`: 標準出力に "LED off" を出力する。
    *   **ステップ4: 待機**
        *   `sleep_ms(250)`: 250ミリ秒待機する。
    *   **ステップ5: I2C再スキャン**
        *   8サイクルごとにI2Cスキャンを再実行し、ローカルHIL/UART取得が起動直後のログを取り逃がしても観測しやすくする。

## 3. データ構造・定数定義
### 3.1 定数
| 定数名 | 値 | 説明 |
| :--- | :--- | :--- |
| `LED_PIN` | 25 | LEDが接続されているGPIOピン番号 (PICO_DEFAULT_LED_PIN) |
| `I2C_SDA_PIN` | 4 | I2C0 SDAとして使用するGPIOピン番号 |
| `I2C_SCL_PIN` | 5 | I2C0 SCLとして使用するGPIOピン番号 |
| `I2C_BAUD_RATE` | 100000 | I2Cバス速度 (100kHz) |

## 4. 回路図詳細 (Wokwi Definition)
`diagram.json` では、外部LEDは接続せず、Pico本体のオンボードLED
(GP25 / `PICO_DEFAULT_LED_PIN`)を使用する。Wokwi上ではI2C題材として
`board-ssd1306` をGP4/GP5に接続し、既定アドレス `0x3C` を検出する。
Wokwi図ではOLEDをPicoの真下寄りに配置し、配線の出どころと画面を確認しやすいレイアウトにする。

```json
"connections": [
  [ "pico:GP0", "$serialMonitor:RX", "", [] ], 
  [ "pico:GP1", "$serialMonitor:TX", "", [] ],
  [ "pico:GP4", "oled1:SDA", "green", [] ],
  [ "pico:GP5", "oled1:SCL", "blue", [] ]
]
```
