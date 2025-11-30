# System Design Document

## 1. System Overview
本システムは、Raspberry Pi Pico (RP2040) を使用した組み込みシステム学習用の最小構成プロジェクトです。
GPIO制御によるLEDの点滅（Lチカ）と、UART経由でのシリアル通信ログ出力を主な機能としています。

## 2. Hardware Architecture

### 2.1 Component List
| Component | Model | Quantity | Note |
|-----------|-------|----------|------|
| MCU | Raspberry Pi Pico | 1 | RP2040 Microcontroller |
| LED | Red LED | 1 | Standard 5mm LED |
| Resistor | 1kΩ | 1 | Current limiting |

### 2.2 Circuit Diagram
Wokwiシミュレータ上の配線定義 (`diagram.json`) は以下の通りです。

*   **Signal Path**:
    `Pico GP2 (Pin 4)` → `Resistor (1kΩ)` → `LED Anode`
*   **Return Path**:
    `LED Cathode` → `Pico GND (Pin 3)`

### 2.3 Pin Assignments
| Pin Name | GP Number | Function | Connection |
|----------|-----------|----------|------------|
| GP2 | 2 | GPIO Output | LED Control (Active High) |
| GND | - | Ground | LED Cathode |
| GP0 | 0 | UART0 TX | Serial Monitor (Default) |
| GP1 | 1 | UART0 RX | Serial Monitor (Default) |

## 3. Software Architecture

### 3.1 Technology Stack
*   **Language**: C++ (C++17 Standard)
*   **SDK**: Raspberry Pi Pico SDK
*   **Build System**: CMake

### 3.2 Control Logic (`blink.cpp`)
プログラムは以下のフローで動作します。

1.  **Initialization**:
    *   `stdio_init_all()`: 標準入出力（UART/USB）の初期化。
    *   `gpio_init(2)`: GP2ピンのGPIO初期化。
    *   `gpio_set_dir(2, GPIO_OUT)`: GP2を出力モードに設定。

2.  **Main Loop**:
    *   **LED ON**: `gpio_put(2, 1)` でHighを出力。
    *   **Log**: "LED on" を標準出力へ送信。
    *   **Wait**: `sleep_ms(250)` で250ミリ秒待機。
    *   **LED OFF**: `gpio_put(2, 0)` でLowを出力。
    *   **Log**: "LED off" を標準出力へ送信。
    *   **Wait**: `sleep_ms(250)` で250ミリ秒待機。

### 3.3 Interfaces
*   **GPIO**: デジタル出力としてLEDを制御。
*   **UART**: ボーレート 115200bps (デフォルト) でデバッグログを出力。

## 4. Project Structure

本プロジェクトのディレクトリ構成と各ファイルの役割は以下の通りです。

```text
.
├── .github/workflows/
│   └── ci.yml              # GitHub Actions CIワークフロー定義 (Build & Test)
├── .vscode/                # VS Code用設定ファイル (Extensions, Settings)
├── build/                  # ビルド成果物出力ディレクトリ (Git除外)
├── blink.cpp               # [Main] アプリケーションのエントリーポイント
├── blink.test.yaml         # [Test] Wokwiオートメーション用テストシナリオ定義
├── build_and_test.sh       # [Script] ローカル/CI兼用の統合ビルド・テストスクリプト
├── CMakeLists.txt          # [Build] CMakeビルド設定ファイル
├── diagram.json            # [Wokwi] ハードウェア構成定義 (Pico, LED, Resistor)
├── pico_sdk_import.cmake   # [SDK] Pico SDKインポート用ヘルパースクリプト
├── wokwi.toml              # [Wokwi] プロジェクト設定 (ファームウェアパス等)
├── README.md               # [Doc] プロジェクト概要・利用手順
└── SYSTEM_DESIGN.md        # [Doc] システム詳細設計書
```

### Key Files Description

*   **`build_and_test.sh`**:
    *   **役割**: 環境差異を吸収し、ワンコマンドでビルドとテストを完遂させるためのスクリプト。
    *   **動作**: `cmake configure` -> `cmake build` -> `ctest` の順に実行。

*   **`diagram.json`**:
    *   **役割**: Wokwiシミュレータが読み込むハードウェア定義。
    *   **重要性**: これが物理的な回路図の代わりとなり、シミュレーションの正当性を保証します。

*   **`blink.test.yaml`**:
    *   **役割**: 「1秒間シミュレーションを実行し、LEDピンの状態を監視する」といったテストシナリオを記述。
    *   **連携**: `wokwi-ci-action` や `wokwi-cli` から参照されます。



## 5. System Architecture Philosophy

本システムは、**"Single Source of Truth"** と **"AI-Driven CI/CD"** の2つの柱で構成されています。

### 5.1 Single Source of Truth
システムを構成する全ての要素が、`pico-sdk-blink` フォルダ一つに集約されています。

| レイヤー | 構成要素 | 役割 |
| :--- | :--- | :--- |
| **ドキュメント** | `README.md`<br>`SYSTEM_DESIGN.md`<br>`CONTRIBUTING.md` | 「何を作るか」「どう動くか」「どう開発するか」の完全な定義。 |
| **ハードウェア** | `diagram.json`<br>`wokwi.toml` | 物理的な回路図の代わりとなる、実行可能なハードウェア定義。 |
| **ソフトウェア** | `blink.cpp`<br>`CMakeLists.txt` | Pico SDKを用いた制御ロジックとビルド定義。 |
| **パイプライン** | `build_and_test.sh`<br>`.github/workflows/ci.yml` | ローカルとCIで**完全に等価な**検証プロセスを保証する仕組み。 |

### 5.2 AI-Driven CI/CD Workflow
開発者がコードを書き、Gitにプッシュする裏側で、以下のプロセスが自動的に回っています。

1.  **Push**: 変更をGitHubに送信。
2.  **CI Trigger**: GitHub Actionsが起動。
3.  **Reproduce**: クラウド上でクリーンな環境を一から構築。
4.  **Build & Test**: ローカルと同じスクリプトでビルドし、サイズチェック等のテストを実行。
5.  **Feedback**: 結果がバッジとしてREADMEに表示される。

この「守られた環境」があるからこそ、AIに大胆なコード修正を指示しても、システムが壊れることを恐れずに開発を進められます。

---
*Documented by Antigravity*

