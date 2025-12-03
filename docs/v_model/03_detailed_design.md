# 詳細設計書 (Detailed Design Document)

## 1. ソフトウェア構造
### 1.1 モジュール構成
本ソフトウェアは単一のソースファイル `blink.cpp` で構成される。

*   **blink.cpp**: メインロジック（初期化、メインループ）を含む。

### 1.2 依存ライブラリ
*   **pico_stdlib**: 標準入出力、GPIO制御、時間管理機能を提供。

## 2. 処理フロー詳細
### 2.1 メイン関数 (`main`)
プログラムのエントリーポイント。以下の順序で処理を実行する。

1.  **初期化処理**
    *   `stdio_init_all()`: 標準入出力（UART/USB）ドライバを初期化する。
    *   `gpio_init(25)`: GP25ピンをGPIOとして初期化する。
    *   `gpio_set_dir(25, GPIO_OUT)`: GP25ピンを出力モードに設定する。

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

## 3. データ構造・定数定義
### 3.1 定数
| 定数名 | 値 | 説明 |
| :--- | :--- | :--- |
| `LED_PIN` | 25 | LEDが接続されているGPIOピン番号 (PICO_DEFAULT_LED_PIN) |

## 4. 回路図詳細 (Wokwi Definition)
`diagram.json` における配線定義の詳細。

```json
"connections": [
  [ "pico:GP0", "$serialMonitor:RX", "", [] ], 
  [ "pico:GP1", "$serialMonitor:TX", "", [] ],
  [ "pico:GP2", "r1:2", "green", [ "v0" ] ],
  [ "r1:1", "led1:A", "green", [ "v0" ] ],
  [ "pico:GND.3", "led1:C", "black", [ "v-19.2", "h9.6" ] ]
]
```
