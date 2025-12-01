# Hardware-in-the-Loop (HIL) Testing Strategy Report

## 1. 概要
本レポートでは、Raspberry Pi Picoの実機を用いた自動テスト（HILテスト）をCI/CDパイプラインに組み込むための調査結果と推奨構成をまとめます。
特に、**Wokwiシミュレーションとの整合性（Parity）** を最優先し、テストシナリオの共通化を目指します。

## 2. 推奨アーキテクチャ: "Unified Test Runner"

Wokwiのテスト定義 (`blink.test.yaml`) を「正」とし、これを実機でも実行可能な仕組みを構築します。

### 2.1 ハードウェア構成
| 役割 | 推奨デバイス | 備考 |
| :--- | :--- | :--- |
| **CI Runner (Host)** | Raspberry Pi 4 Model B (4GB以上) or Pi 5 | GitHub ActionsのSelf-hosted Runnerとして稼働。 |
| **Debug Probe** | Raspberry Pi Pico (Picoprobe) | ターゲットへの書き込み・デバッグ・UART通信を担当。 |
| **Target Device (DUT)** | Raspberry Pi Pico | テスト対象の実機。 |

**接続図:**
```mermaid
graph LR
    GitHub[GitHub Actions] -- Internet --> Runner[Raspberry Pi 4 (Runner)]
    Runner -- USB --> Probe[Pico (Picoprobe)]
    Probe -- SWD/UART --> Target[Pico (Target)]
    Runner -- GPIO --> Target
```
*   **注記**: `expect-pin` (GPIO状態確認) を行うため、Runner (Pi 4) のGPIOピンとTarget PicoのGPIOピンを物理的に接続する必要があります。

### 2.2 ソフトウェア構成
1.  **GitHub Actions Runner**: Raspberry Pi OS上で動作。
2.  **OpenOCD**: ファームウェア書き込み用。
3.  **Custom Test Runner (Python)**: `blink.test.yaml` をパースし、実機に対してテストを実行するスクリプト。

## 3. Wokwi Parity の実現方法

`wokwi-cli` はシミュレーション専用であり、実機には対応していません。
そのため、**`blink.test.yaml` を解釈して実機を操作するPythonスクリプト (`hil_runner.py`)** を開発することを提案します。

### 3.1 `blink.test.yaml` と実機操作のマッピング

| Wokwi Command | Action on Physical Hardware | Implementation |
| :--- | :--- | :--- |
| `wait-serial: "text"` | UART出力を監視し、指定文字列を待つ | `pyserial` でPicoprobeのUARTポートをRead |
| `expect-pin: {pin: A, value: 1}` | 指定ピンの電圧レベルを確認する | Runner (Pi 4) のGPIO入力でH/L判定 (`gpiozero`等) |
| `set-pin: {pin: B, value: 1}` | 指定ピンに電圧を印加する | Runner (Pi 4) のGPIO出力でH/L制御 |
| `wait: 1000` | 待機する | `time.sleep(1.0)` |

### 3.2 開発が必要なコンポーネント
*   **`hil_runner.py`**:
    *   YAMLパーサー: `blink.test.yaml` を読み込む。
    *   Serial Handler: Picoprobe経由のシリアル通信を管理。
    *   GPIO Handler: Raspberry Pi 4のGPIOヘッダーを制御。

## 4. 実現へのステップ

### Phase 0: 手動検証 (Manual Verification) - **Current Focus**
自動化の前に、手動で実機接続とテストロジックの検証を行います。
1.  PCとPicoをUSB接続する。
2.  `blink.uf2` を手動で書き込む。
3.  ターミナルソフトでUART出力を監視し、"LED on/off" のログを確認する。
4.  テスター等でGPIO電圧を確認する。
*目的*: ハードウェアの挙動特性（起動時間、ログ出力タイミング等）を把握し、自動化スクリプトの仕様を固める。

### Phase 1: Runnerの構築
1.  Raspberry Pi 4/5 に Raspberry Pi OS (64-bit) をインストール。
2.  GitHubリポジトリの設定画面から「Self-hosted runner」を追加。
3.  必要なツール (`openocd`, `gdb-multiarch`, `python3`, `python3-serial`, `python3-gpiozero`, `python3-yaml`) をインストール。

### Phase 2: ハードウェア結線
1.  **SWD**: Picoprobe <-> Target (書き込み用)
2.  **UART**: Picoprobe <-> Target (ログ監視用)
3.  **GPIO**: Runner (Pi 4) <-> Target (テスト用信号線)
    *   例: Target GP2 (LED) <-> Pi 4 GPIO 27 (Input)

### Phase 3: Runnerスクリプト開発
`hil_runner.py` を作成し、`blink.test.yaml` を読み込んで実行するロジックを実装。

## 5. 結論
この構成により、**「Wokwiでテストシナリオを作成・検証」→「同じシナリオで実機テスト」** という理想的なフローが実現できます。
専用のRunnerスクリプト開発という初期コストはかかりますが、長期的な保守性と整合性の観点から最も推奨されるアプローチです。
