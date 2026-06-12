# 基本設計書 (Basic Design Document)

## 1. システムアーキテクチャ
本システムは、シングルチップマイコン上で動作する単一のアプリケーションとして構成される。

### 1.1 全体構成図
```mermaid
graph LR
    User[User / Serial Monitor] <-->|UART| Pico[Raspberry Pi Pico]
    Pico -->|GP25| LED[Onboard LED]
```

## 2. ハードウェア構成
### 2.1 コンポーネント一覧
| コンポーネント | 型番/仕様 | 数量 | 備考 |
| :--- | :--- | :--- | :--- |
| MCU | Raspberry Pi Pico (RP2040) | 1 | メインコントローラ |
| LED | Pico Onboard LED (GP25) | 1 | 状態表示用 |

### 2.2 接続定義
外部配線とボード内蔵機能の扱いは以下の通り。

*   **LED接続**:
    *   Pico Onboard LED (GP25)。`diagram.json` には外部LED配線を置かない。

## 3. 外部インターフェース設計
### 3.1 GPIOインターフェース
*   **使用ピン**: GP25 (Onboard LED)
*   **方向**: 出力 (Output)
*   **論理**: 正論理 (Active High) - Highで点灯、Lowで消灯

### 3.2 シリアル通信インターフェース (UART)
*   **使用ピン**: GP0 (TX), GP1 (RX) - Pico SDKデフォルト
*   **通信設定**:
    *   ボーレート: 115200 bps
    *   データビット: 8
    *   ストップビット: 1
    *   パリティ: なし
    *   フロー制御: なし
*   **用途**: デバッグログ出力 ("LED on", "LED off")
