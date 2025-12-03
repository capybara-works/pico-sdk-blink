# Pico SDK Blink Project

![Build and test](https://github.com/capybara-works/pico-sdk-blink/actions/workflows/ci.yml/badge.svg)

Raspberry Pi Pico (RP2040) 用のLED点滅サンプルプロジェクトです。
デフォルトでオンボードLED (GP25) を点滅させます。
Wokwiシミュレータでの動作確認、およびGitHub ActionsによるCI/CDパイプラインに対応しています。

## 💡 コンセプト (Concept)

**"Embedded Vibe Coding with AI-driven CI/CD"**

本プロジェクトは、単なるLチカのサンプルではなく、**AIと協調して高速に組み込み開発を行うための実験的環境**です。

*   **Vibe Coding**: 人間は「意図（Vibe）」と「設計」に集中し、実装の細部はAIに任せるスタイル。
*   **AI-Driven**: 環境構築、ビルドスクリプト作成、ドキュメント生成をAIが主導。
*   **Robust Foundation**: ローカルとCIで統一されたビルド・テスト環境 (`build_and_test.sh`) が、AI生成コードの動作を即座に保証します。

### メリットと課題 (Pros & Cons)

**🟢 メリット (Pros)**
1.  **環境構築フリー**: `build_and_test.sh` と Codespaces により、誰でも即座に開発開始可能。
2.  **AI親和性**: ハード(JSON)・ソフト(C++)・ビルド(CMake)が全てテキスト管理され、AIによる全レイヤーの修正が容易。
3.  **高速なフィードバック**: 統一されたCI環境により、AIが生成したコードの品質を即座に検証可能。

**🔴 課題 (Cons)**
1.  **テスト深度**: CIでWokwi機能テスト（Lチカの挙動確認など）は実装済みですが、`WOKWI_CLI_TOKEN` シークレットの設定が必要です。より複雑なシナリオテスト（タイミング検証、複数サイクル確認等）への拡張も検討の余地があります。
2.  **シミュレータの限界**: 実機特有のノイズやタイミング問題は再現不可。
3.  **ブラックボックス化**: 環境が便利すぎるため、低レイヤー技術の理解がおろそかになるリスク。

## 📋 前提条件 (Prerequisites)

このプロジェクトをローカルでビルド・開発するには、以下のツールが必要です。

*   **Pico SDK**: Raspberry Pi Pico SDK (v1.5.0以上推奨, CIはv2.0.0使用)
*   **CMake**: ビルドシステム
*   **GCC ARM Toolchain**: クロスコンパイラ (`arm-none-eabi-gcc`)
*   **VS Code**: 推奨エディタ (Wokwi拡張機能利用のため)
*   **Node.js**: ローカルでのWokwi自動テスト実行に必要

## 🔑 Wokwi Token Setup

Wokwiの自動テスト（ローカルおよびCI）を実行するには、APIトークンが必要です。

1.  **トークンの取得**:
    [https://wokwi.com/dashboard/ci](https://wokwi.com/dashboard/ci) にアクセスし、トークンを取得してください。

2.  **ローカル環境での設定**:
    ターミナルで以下のコマンドを実行します（`.zshrc` 等への追記を推奨）。
    ```bash
    export WOKWI_CLI_TOKEN="your_token_here"
    ```

3.  **CI環境 (GitHub Actions) での設定**:
    1.  リポジトリの **Settings** > **Secrets and variables** > **Actions** に移動。
    2.  **New repository secret** をクリック。
    3.  **Name**: `WOKWI_CLI_TOKEN`
    4.  **Value**: 取得したトークンを入力。

## ☁️ クラウド開発 (GitHub Codespaces)

本プロジェクトは **GitHub Codespaces** に対応しています。
ブラウザ上でVS Code環境を即座に立ち上げ、環境構築なしで開発を開始できます。

1.  GitHubリポジトリの **[<> Code]** ボタンをクリック。
2.  **[Codespaces]** タブを選択し、**[Create codespace on main]** をクリック。
3.  自動的にPico SDK等のツールチェーンがセットアップされます。

## 🛠️ ローカル開発 (Local Development)

### ビルドとテスト (推奨)

ローカル環境とCI環境の差異をなくすため、統合スクリプト `build_and_test.sh` の使用を推奨します。
このスクリプトは、CMakeのConfigure、Build、およびCTestによるテスト実行を一括で行います。

```bash
# 実行権限の付与（初回のみ）
chmod +x build_and_test.sh

# ビルドとテストの実行
./build_and_test.sh
```

### 手動ビルド

従来のCMakeコマンドによるビルドも可能です。

```bash
mkdir -p build
cd build
cmake ..
make -j4
```

## 🚀 CI/CD パイプライン

GitHub Actions (`.github/workflows/ci.yml`) により、以下のプロセスが自動化されています。

1.  **環境構築**: 必要なツールチェーンとPico SDK (v2.0.0) のセットアップ。
2.  **ビルド & テスト**: ローカルと同じ `build_and_test.sh` を使用して実行。
3.  **アーティファクト保存**: ビルド成果物 (`blink.uf2`, `blink.elf`) を保存。
4.  **Wokwi統合テスト**: シミュレータ環境でLEDの点滅動作を自動検証 (要 `WOKWI_CLI_TOKEN` シークレット設定)。

## 💻 Wokwi シミュレーション

[Wokwi for VS Code](https://marketplace.visualstudio.com/items?itemName=wokwi.wokwi-vscode) を使用して、実機なしで動作確認が可能です。

1.  VS Codeでプロジェクトを開く。
2.  `diagram.json` を開くか、コマンドパレット (F1) から **"Wokwi: Start Simulator"** を選択。
3.  LEDが点滅することを確認。

## 🔧 実機テスト (Hardware-in-the-Loop)

Debug Probeを使用した実機での自動テストが可能です (Phase 0完了)。

### 必要なハードウェア
*   **Raspberry Pi Debug Probe** (CMSIS-DAPv2対応)
*   **Raspberry Pi Pico** (テスト対象)
*   **接続ケーブル**: SWD (3-pin) + UART (3-pin)

### セットアップ

#### 1. ツールのインストール

**macOS:**
```bash
brew install open-ocd
pip3 install pyserial pyyaml
```

**Linux:**
```bash
sudo apt install openocd python3-pip
pip3 install pyserial pyyaml
```

#### 2. ハードウェア接続
1.  PC ↔ Debug Probe (USB接続)
2.  Debug Probe ↔ Target Pico (SWD + UART接続)

詳細な配線情報は `docs/HIL_RESEARCH_REPORT.md` を参照。

### 実行方法

```bash
# UARTポートを確認
ls /dev/cu.usbmodem*  # macOS
ls /dev/ttyACM*       # Linux

# テスト実行
python3 hil_runner.py \
  --test blink.test.yaml \
  --elf build/blink.elf \
  --uart /dev/cu.usbmodem14402  # 実際のポートに置き換え
```

### 利用可能なツール

*   **`hil_runner.py`**: 完全自動E2Eテスト (推奨)
*   **`uart_monitor.py`**: UART出力のリアルタイム監視
*   **`gpio_test.py`**: GPIO状態の検証

**詳細:** `docs/HARDWARE_INTEGRATION_TEST_REPORT.md` および `docs/HIL_RESEARCH_REPORT.md` を参照。


## 🤖 AIアシスタント活用ガイド

このプロジェクトの開発において、AIアシスタント（Antigravity等）は以下の場面で活用できます。

### 1. 環境構築トラブルシューティング
ビルドエラーが発生した場合、エラーログをそのまま共有することで、原因（パス設定漏れ、ツールチェーン不整合など）の特定と解決策の提示が可能です。

### 2. Wokwi構成の変更
新しいセンサーやパーツを追加したい場合、「Wokwiでボタンを追加してGP15に接続したい」と指示することで、`diagram.json` の定義と配線情報を生成できます。

### 3. CMake設定の管理
ライブラリの追加やビルドオプションの変更が必要な場合、`CMakeLists.txt` の適切な修正箇所を提案できます。

---
*Documented by Antigravity*
