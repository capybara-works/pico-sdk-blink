# Embedded AI Agent Lab (Raspberry Pi Pico)

![Build and test](https://github.com/capybara-works/pico-sdk-blink/actions/workflows/ci.yml/badge.svg)

Raspberry Pi Pico (RP2040) を題材にした、**個人用 Embedded AI Agent Lab** です。
題材ファームウェアはオンボードLED (GP25) を点滅させる最小構成ですが、
本リポジトリの主目的はLチカそのものではなく、AI生成コードを
**ビルド → シミュレーション(Wokwi/CI) → 実機書き込み → 観測(UART/GDB/必要に応じてGPIO・ロジックアナライザ) → 証拠保存 → AIによる判定**
という閉ループで検証できる、最小で再現性のあるPoC基盤を作ることです。

```text
AIがコードを変更する
  ↓ scripts/build.sh           (ビルド + ctest + 任意Wokwi)
  ↓ scripts/flash.sh           (実機書き込み)
  ↓ scripts/run_hil.sh         (実機HILテスト)
  ↓ scripts/capture_uart.sh    (UART観測)
  ↓ scripts/gdb_snapshot.sh    (GDBレジスタ+バックトレース取得)
  ↓ scripts/capture_logic_i2c.sh (ロジックアナライザ: 未有効ならスタブ)
  ↓ evidence/latest/           (ログ + JSON として証拠を保存)
  ↓ scripts/summarize_evidence.py → evidence/latest/verification.md
AIが証拠を読んで成功/失敗/原因候補を判断する
```

成功判定は必ず証拠(ログ・JSON・実測結果)に基づきます。詳細は
[docs/operations/AGENT_OPERATION.md](docs/operations/AGENT_OPERATION.md) と
[docs/operations/TEST_EVIDENCE_POLICY.md](docs/operations/TEST_EVIDENCE_POLICY.md) を参照してください。

## 🔁 証拠ベース検証 (Evidence-Based Verification)

```bash
# ローカル環境依存値の設定(初回のみ、実機がある場合)
cp config/hardware.example.yaml config/hardware.local.yaml

# 実機なし (安全: ハードウェアには一切触れない)
scripts/verify_all.sh

# 実機あり (明示的に有効化した場合のみ flash/HIL/UART/GDB を実行)
PICO_HARDWARE=1 scripts/verify_all.sh

# ロジックアナライザあり (実測を明示的に有効化)
PICO_HARDWARE=1 PICO_LOGIC_ANALYZER=1 scripts/verify_all.sh

# 個別実行も可能 (実機系は同じく PICO_HARDWARE=1 が必要)
scripts/build.sh                       # → build/ctest/wokwi のログ + result.json
PICO_HARDWARE=1 scripts/run_hil.sh     # → evidence/latest/hil_result.json
python3 scripts/summarize_evidence.py  # → evidence/latest/verification.md

# CIで生成されたWokwi統合済み証拠を取得 (GitHub CLI / gh auth login が必要)
scripts/fetch_ci_evidence.sh           # → artifacts/latest/evidence-with-wokwi/<run_id>/
```

**安全ゲート:** 実機操作(flash/HIL/UART/GDB)は `PICO_HARDWARE=1`、
ロジックアナライザ実測は `PICO_LOGIC_ANALYZER=1` が明示された場合のみ実行されます。
未指定なら各ステップは `skip` / `stub` を証拠として記録します(偽の成功にはなりません)。

**結果の読み方:** `verification.md` は最終要約であり、一次証拠は
`build.log` や `*_result.json` などの個別ファイルです。

| status | 意味 |
|---|---|
| `pass` | 実際に実行され、検証が通った |
| `fail` | 実際に実行され、失敗した(ログに理由が残る) |
| `skip` | **未実行**(実機・ツール・許可がない) — 成功ではない |
| `stub` | サンプル・代替データによる仮実行 — **実測ではない** |
| `partial` | (Overall) 一部のみpass。skip/stub/未実施が混在 |

`evidence/latest/` はGit管理外の作業領域で、代表サンプルは
[evidence/samples/](evidence/samples/) にあります(実測/合成の来歴つき)。
CIで生成された `evidence-with-wokwi` artifact は `scripts/fetch_ci_evidence.sh` で
`artifacts/latest/evidence-with-wokwi/<run_id>/` に取得できます。

## 💡 コンセプト (Concept)

**"Embedded Vibe Coding with AI-driven CI/CD"**

本プロジェクトは、単なるLチカのサンプルではなく、**AIと協調して高速に組み込み開発を行うための実験的環境**です。

*   **Vibe Coding**: 人間は「意図（Vibe）」と「設計」に集中し、実装の細部はAIに任せるスタイル。
*   **AI-Driven**: 環境構築、ビルドスクリプト作成、ドキュメント生成をAIが主導。
*   **Robust Foundation**: ローカルとCIで統一されたビルド・テスト入口 (`scripts/build.sh`, `scripts/verify_all.sh`) が、AI生成コードの動作を即座に保証します。

### メリットと課題 (Pros & Cons)

**🟢 メリット (Pros)**
1.  **環境構築フリー**: `scripts/build.sh` と Codespaces により、誰でも即座に開発開始可能。
2.  **AI親和性**: ハード(JSON)・ソフト(C++)・ビルド(CMake)が全てテキスト管理され、AIによる全レイヤーの修正が容易。
3.  **高速なフィードバック**: 統一されたCI環境により、AIが生成したコードの品質を即座に検証可能。

**🔴 課題 (Cons)**
1.  **テスト深度**: CIでWokwiシナリオテスト（UARTログ `LED on` / `LED off` の確認）は実装済みですが、`WOKWI_CLI_TOKEN` シークレットの設定が必要です。GPIO状態・周期精度・複数サイクル確認などは今後の拡張余地があります。
2.  **シミュレータの限界**: 実機特有のノイズやタイミング問題は再現不可。
3.  **ブラックボックス化**: 環境が便利すぎるため、低レイヤー技術の理解がおろそかになるリスク。

## 📋 前提条件 (Prerequisites)

このプロジェクトをローカルでビルド・開発するには、以下のツールが必要です。

*   **Pico SDK**: Raspberry Pi Pico SDK (DevContainer/CIはv2.0.0固定。手動ローカルもv2.0.0推奨)
*   **CMake**: ビルドシステム
*   **GCC ARM Toolchain**: クロスコンパイラ (`arm-none-eabi-gcc`)
*   **VS Code**: 推奨エディタ (Wokwi拡張機能利用のため)
*   **Node.js**: ローカルでのWokwi自動テスト実行に必要

## 🔑 Wokwi Token Setup

Wokwiの自動テストをCIで実行するには、APIトークンが必要です。ローカルでは任意で、
未設定の場合 `scripts/test_wokwi.sh` はWokwiステップをskipし、`scripts/build.sh` 全体はビルドとCTestを継続します。

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

ローカル環境とCI環境の差異をなくすため、証拠付き入口 `scripts/build.sh` の使用を推奨します。
このスクリプトは、CMakeのConfigure、Build、CTest、および任意のWokwiシナリオテストを一括で行い、`evidence/latest/` に個別ログと結果JSONを残します。

```bash
# 実行権限の付与（初回のみ）
chmod +x scripts/*.sh

# ビルドとテストの実行
scripts/build.sh
```

`build_and_test.sh` は互換用wrapperとして残していますが、新しい自動化では `scripts/build.sh` を使用してください。

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
2.  **ビルド & テスト**: `scripts/ci_phase1_smoke.sh` 経由で `scripts/verify_all.sh` を実行し、ビルド・CTest・証拠生成を確認。
3.  **アーティファクト保存**: ビルド成果物 (`blink.uf2`, `blink.elf`) と evidence を保存。
4.  **Wokwi統合テスト**: シミュレータ環境でUARTログシナリオを自動検証し、結果を `evidence-with-wokwi` artifact に統合 (要 `WOKWI_CLI_TOKEN` シークレット設定)。

## 💻 Wokwi シミュレーション

[Wokwi for VS Code](https://marketplace.visualstudio.com/items?itemName=wokwi.wokwi-vscode) を使用して、実機なしで動作確認が可能です。

1.  VS Codeでプロジェクトを開く。
2.  `diagram.json` を開くか、コマンドパレット (F1) から **"Wokwi: Start Simulator"** を選択。
3.  Serial Monitor に `LED on` / `LED off` が出力されることを確認。

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

詳細な配線情報は `docs/reports/HIL_RESEARCH_REPORT.md` を参照。

### 実行方法

```bash
# UARTポートを確認
ls /dev/cu.usbmodem*  # macOS
ls /dev/ttyACM*       # Linux

# テスト実行 (推奨: scripts/run_hil.sh 経由)
PICO_HARDWARE=1 PICO_UART_PORT=/dev/cu.usbmodem14402 scripts/run_hil.sh  # 実際のポートに置き換え

# または低レベル確認として直接実行
python3 tools/hil/hil_runner.py \
  --test blink.test.yaml \
  --elf build/blink.elf \
  --uart /dev/cu.usbmodem14402
```

### 利用可能なツール (`tools/hil/`)

*   **`hil_runner.py`**: 完全自動E2Eテスト (入口: `scripts/run_hil.sh`)
*   **`uart_monitor.py`**: UART出力の監視・パターン検証 (入口: `scripts/capture_uart.sh`)
*   **`gpio_test.py`**: GPIO状態の補助検証(手動/調査用)

**詳細:** `docs/guides/HARDWARE_SETUP.md`、`docs/reports/HARDWARE_INTEGRATION_TEST_REPORT.md` および `docs/reports/HIL_RESEARCH_REPORT.md` を参照。

## 📚 ドキュメント (Docs)

文書の全体像と管理ポリシーは **[docs/README.md](docs/README.md)** を参照してください。
規程は `docs/operations/`、手順書は `docs/guides/`、設計メモは `docs/design/`、
調査レポート(Record)は `docs/reports/` にあります。主要な文書:

| ドキュメント | 内容 |
|---|---|
| [docs/operations/AGENT_OPERATION.md](docs/operations/AGENT_OPERATION.md) | AIエージェントの運用ルール |
| [docs/operations/TEST_EVIDENCE_POLICY.md](docs/operations/TEST_EVIDENCE_POLICY.md) | 何を合格証拠と認めるか |
| [docs/guides/HARDWARE_SETUP.md](docs/guides/HARDWARE_SETUP.md) | Pico / Debug Probe / UART / SWD 接続・既知の落とし穴 |
| [docs/guides/LOGIC_ANALYZER_SETUP.md](docs/guides/LOGIC_ANALYZER_SETUP.md) | FX2LP系ロジックアナライザ + sigrok (将来) |
| [docs/design/MCP_SETUP.md](docs/design/MCP_SETUP.md) | MCPサーバー化の設計メモ (将来) |
| [docs/reports/AGENT_LAB_PHASE1_REPORT.md](docs/reports/AGENT_LAB_PHASE1_REPORT.md) | Phase 1 実装・検証レポート (実測結果・調査記録) |


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
