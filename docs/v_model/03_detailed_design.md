# 詳細設計書 (Detailed Design Document)

## 1. ソフトウェア構造
### 1.1 モジュール構成
本ソフトウェアはメイン処理の `blink.cpp` と、最小SSD1306ドライバの
`ssd1306_min.h` で構成される。

*   **blink.cpp**: メインロジック（初期化、メインループ）を含む。
*   **ssd1306_min.h**: 128x64 SSD1306 OLEDへの初期化・描画転送・
    フレームバッファCRC算出・I2C戻り値ログ・OLED復旧/診断モードを提供する。

### 1.2 依存ライブラリ
*   **pico_stdlib**: 標準入出力、GPIO制御、時間管理機能を提供。
*   **hardware_i2c**: I2C0を使ったアドレススキャン、OLED検出、
    バス復旧、低速リトライを提供。
*   **hardware_adc**: 起動時自己診断(POST)でVSYS(ADC3)・内蔵温度(ADC4)を測定する。

## 2. 処理フロー詳細
### 2.1 メイン関数 (`main`)
プログラムのエントリーポイント。以下の順序で処理を実行する。

1.  **初期化処理**
    *   `stdio_init_all()`: 有効化された標準入出力を初期化する。本プロジェクトではUARTを有効、USB stdioを無効にしている。
    *   `gpio_init(25)`: GP25ピンをGPIOとして初期化する。
    *   `gpio_set_dir(25, GPIO_OUT)`: GP25ピンを出力モードに設定する。
    *   `i2c_init(i2c0, 100000)`: I2C0を100kHzで初期化する。
    *   GP4をSDA、GP5をSCLとして設定し、内部pull-upを有効にする。
    *   必要時のみ `OLED_STARTUP_BUS_DIAG` を有効化し、外部pull-up、
        速度別スキャン、低速bit-bang ACK確認をUARTへ出力する。
        通常はOLED表示中のバス刺激と起動遅延を避けるため無効にしている。
    *   I2Cアドレススキャンを実行し、検出したアドレスをUARTへ出力する。
        `0x3C` が見つからない場合は、GP4/GP5を一時的にGPIOへ戻して
        SCLを9クロック送出し、STOP条件を生成してから100kHzで再試行する。
        それでも見つからない場合は50kHzで再試行する。
        0x3Cのプローブ結果は `OLED_PROBE ... ack=<0|1>` として明示する。
    *   **POST (Power-On Self-Test)**: `run_post()` が外付け部品ゼロで実機状態を計測し、
        1行のテキストで出力する: `POST fw=... gp29_raw=.. gp29_adc_mv=.. vsys_est_mv=<ADC3:VSYS/3×3> temp_mc=<ADC4内蔵温度>
        vbus=<GP24> i2c_oled=<0x3C検出>`。AI/人間がUART証拠から物理状態を読めるようにする
        (詳細: `docs/design/CHEAP_AUTONOMY_LEVERS.md` L1)。

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
    *   **ステップ5: OLED更新と再検出**
        *   OLEDが検出・初期化済みの場合だけ描画を更新し、`OLED_RENDER ... fbcrc=...`
            と `OLED_SHOW result=... pages_ok=... pages_fail=...` をUARTへ出力する。
            `fbcrc` はPico内部フレームバッファの証跡であり、実表示の証拠ではない。
            実I2C転送は `OLED_CMD` / `OLED_CMD2` / `OLED_PAGE` の戻り値で判定する。
        *   初期化直後と描画失敗時は `ssd1306_recover()` を実行し、display off、
            RAM内容表示、normal display、charge pump、display on、全黒送信、
            既知パターン送信の結果を `OLED_RECOVER` として記録する。
        *   OLED未初期化時だけ、8サイクルごとにI2Cスキャン + バス復旧 +
            低速リトライを実行する。初期化済みOLEDに対して定期スキャンを
            重ねないことで、表示中のSSD1306状態を不要に刺激しない。

## 3. データ構造・定数定義
### 3.1 定数
| 定数名 | 値 | 説明 |
| :--- | :--- | :--- |
| `LED_PIN` | 25 | LEDが接続されているGPIOピン番号 (PICO_DEFAULT_LED_PIN) |
| `I2C_SDA_PIN` | 4 | I2C0 SDAとして使用するGPIOピン番号 |
| `I2C_SCL_PIN` | 5 | I2C0 SCLとして使用するGPIOピン番号 |
| `I2C_BAUD_RATE` | 100000 | I2Cバス速度 (100kHz) |
| `I2C_RECOVERY_BAUD_RATE` | 50000 | OLED不検出時の低速リトライ速度 (50kHz) |
| `OLED_STARTUP_BUS_DIAG` | false | 起動時にI2Cバス診断を出力するか |
| `OLED_DIAG_ENABLE_SWAPPED_SCAN` | false | 明示的なSDA/SCL入れ替わり確認時のみ、入れ替えbit-bang scanを許可するか |
| `OLED_LIVE_PROBE_WHEN_ABSENT` | true | OLED未検出時に簡易ACK/外部pull-upを継続表示するか |

POSTで使う固定ピン: ADC3=GP29(VSYS/3), ADC4=内蔵温度センサ, GP24=VBUSセンス。

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
