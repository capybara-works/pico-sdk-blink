# System Design Document: AI-Driven Embedded Platform

## 1. Project Structure

本プロジェクトのディレクトリ構成と各ファイルの役割は以下の通りです。

```text
.
├── .github/workflows/
│   └── ci.yml              # GitHub Actions CIワークフロー定義 (Build & Test)
├── .vscode/                # VS Code用設定ファイル (Extensions, Settings)
├── build/                  # ビルド成果物出力ディレクトリ (Git除外)
├── config/
│   └── hardware.example.yaml # [Config] ハードウェア設定テンプレート (local版はGit除外)
├── docs/                   # [Doc] ドキュメント群 (docs/README.md が文書マップ)
│   ├── operations/         # [Rule] 運用規程 (AI運用ルール・証拠ポリシー)
│   ├── guides/             # [Guide] セットアップ・手順書 (Living)
│   ├── design/             # [Design] 設計メモ (MCP化方針 等)
│   ├── reports/            # [Record] 調査・検証レポート (書き換えない記録)
│   ├── v_model/            # [Product] アプリケーション仕様書
│   └── v_model_environment/# [Factory] 環境仕様書
├── evidence/
│   ├── latest/             # [Evidence] 実行ごとの証拠 (ログ+JSON, Git除外)
│   └── samples/            # [Evidence] 学習・解析用の代表サンプル (Git管理)
├── scripts/                # [Script] 証拠ベース検証の入口 (build/flash/HIL/UART/GDB/ロジアナ)
│   └── verify_all.sh       # [Script] 検証ループ一括実行 → verification.md 生成
├── tools/
│   ├── hil/                # [HIL] 実機テスト実装本体 (hil_runner/uart_monitor/gpio_test)
│   └── mcp_server/         # [Future] MCPサーバー設計メモ (実装は将来フェーズ)
├── blink.cpp               # [Main] アプリケーションのエントリーポイント (Sample)
├── blink.test.yaml         # [Test] Wokwi/HIL共用テストシナリオ定義
├── build_and_test.sh       # [Script] ローカル/CI兼用の統合ビルド・テストスクリプト
├── CLAUDE.md               # [Doc] AIエージェント向けエントリポイント
├── CMakeLists.txt          # [Build] CMakeビルド設定ファイル
├── diagram.json            # [Wokwi] ハードウェア構成定義
├── pico_sdk_import.cmake   # [SDK] Pico SDKインポート用ヘルパースクリプト
├── wokwi.toml              # [Wokwi] プロジェクト設定 (ファームウェアパス等)
├── README.md               # [Doc] プロジェクト概要・利用手順
└── SYSTEM_DESIGN.md        # [Doc] プラットフォーム設計書 (本ドキュメント)
```

### Key Files Description

*   **`build_and_test.sh`**:
    *   **役割**: 環境差異を吸収し、ワンコマンドでビルドとテストを完遂させるためのスクリプト。
    *   **動作**: `cmake configure` -> `cmake build` -> `ctest` の順に実行。

*   **`diagram.json`**:
    *   **役割**: Wokwiシミュレータが読み込むハードウェア定義。
    *   **重要性**: シミュレーション上の外部接続(UART等)を明示します。オンボードLED(GP25)はPico本体側の機能として扱います。

*   **`blink.test.yaml`**:
    *   **役割**: Wokwi/HILで共通利用するテストシナリオを記述。現状はUARTログ (`LED on` / `LED off`) の到達確認が中心です。
    *   **連携**: `wokwi-ci-action` や `wokwi-cli` から参照されます。

## 2. System Architecture Philosophy

本システムは、**"Single Source of Truth"** と **"AI-Driven CI/CD"** の2つの柱で構成されています。

### 2.1 Single Source of Truth
システムを構成する全ての要素が、単一のリポジトリに集約されています。

| レイヤー | 構成要素 | 役割 |
| :--- | :--- | :--- |
| **ドキュメント** | `docs/`<br>`SYSTEM_DESIGN.md` | 「何を作るか」「どう動くか」「どう開発するか」の完全な定義。 |
| **ハードウェア** | `diagram.json`<br>`wokwi.toml` | 物理的な回路図の代わりとなる、実行可能なハードウェア定義。 |
| **ソフトウェア** | `*.cpp`<br>`CMakeLists.txt` | Pico SDKを用いた制御ロジックとビルド定義。 |
| **パイプライン** | `build_and_test.sh`<br>`.github/workflows/ci.yml` | DevContainer/CIを中心に、同じ入口スクリプトで検証する仕組み。手動ローカル環境はツールバージョン差分があり得るため証拠で確認する。 |
| **検証証拠** | `scripts/`<br>`evidence/` | 実機・シミュレーションの観測結果をログ+JSONとして保存し、AI/人間が証拠に基づいて成否判定する仕組み (`docs/operations/TEST_EVIDENCE_POLICY.md`)。 |

### 2.2 AI-Driven CI/CD Workflow
開発者がコードを書き、Gitにプッシュする裏側で、以下のプロセスが自動的に回っています。

1.  **Push**: 変更をGitHubに送信。
2.  **CI Trigger**: GitHub Actionsが起動。
3.  **Reproduce**: クラウド上でクリーンな環境を一から構築。
4.  **Build & Test**: ローカルと同じスクリプトでビルドし、サイズチェック等のテストを実行。
5.  **Feedback**: 結果がバッジとしてREADMEに表示される。

この「守られた環境」があるからこそ、AIに大胆なコード修正を指示しても、システムが壊れることを恐れずに開発を進められます。

### 2.3 Evidence-Based Verification (Phase 1: Embedded AI Agent Lab)

本リポジトリは単なるPico Blinkサンプルではなく、**Embedded AI Agent Lab** です。
目的は、AI生成コードを「ビルド → シミュレーション → 実機 → 観測 → 証拠保存 → 裁可」
という証拠ベース検証ループに載せ、**人間とAIが同じ証拠を見て成否を判断できる**ようにすることです。

```text
VS Code / AI Agent
  ↓
scripts/ (固定された操作入口)  ※将来は MCP tools がこの薄いラッパーになる
  ↓
build / flash / HIL / UART / GDB / Logic Analyzer
  ↓
evidence/latest/  (ログ + 結果JSON)
  ↓
verification.md  (自動生成の最終要約)
  ↓
AI / human review (証拠に基づく裁可)
```

構成要素の役割:

| 要素 | 役割 |
| :--- | :--- |
| `scripts/` | AIと人間が使う**固定操作入口**。任意シェル実行の代替であり、各入口が成功/失敗を終了コードと結果JSONで返す |
| `evidence/latest/` | 実行ごとの生成証拠置き場。**Git管理しない**(`.gitkeep`のみ) |
| `evidence/samples/` | 教材・再現・発表用の代表証拠(来歴を `samples/README.md` に明記) |
| `config/hardware.example.yaml` | 設定テンプレート(Git管理)。コピーして作る `hardware.local.yaml` にローカル環境値を書く(Git管理外) |
| `tools/hil/` | 実機テストの実装本体(`scripts/` がこれをラップする) |
| `tools/mcp_server/` | 将来のMCP化の入口。**MCPは本体ではなく、scriptsを安全に呼ぶ薄いラッパー**。任意シェル実行ツールは公開しない |

安全ゲート(明示的な許可なしに実機を触らない):

| 環境変数 | 有効化される操作 |
| :--- | :--- |
| `PICO_HARDWARE=1` | flash / HIL / UART / GDB の実機操作 |
| `PICO_LOGIC_ANALYZER=1` | ロジックアナライザの実測キャプチャ |

結果ステータスの定義(詳細: `docs/operations/TEST_EVIDENCE_POLICY.md`):

- `pass` — 実際に実行され検証が通った / `fail` — 実際に実行され失敗した
- `skip` — **未実行**(成功ではない) / `stub` — サンプルによる仮実行(**実測ではない**)
- `partial` — (Overall) 一部のみpass

なお、ロジックアナライザは**観測手段の一つでありオシロスコープではありません**。
デジタルタイミングのみ観測可能で、アナログ波形・電圧・ノイズの測定はできません
(`docs/guides/LOGIC_ANALYZER_SETUP.md`)。

## 3. Core Philosophy: The Agentic Embedded Platform

本システムは、単なる開発テンプレートではなく、**「AIエージェントが物理世界（Embedded System）を自律的にハックするためのプラットフォーム」**として設計されています。

### 3.1 Virtual Embodiment (身体性の仮想化)
**〜AIに「目」と「指」を与える〜**
従来のLLMはテキストしか扱えず、物理的な現象を観測できませんでした。本システムでは、Wokwiシミュレータとテストスクリプトの統合により、UARTログやGDBスナップショットなどの観測結果を**「テキストベースの論理的事実」**に変換しています。これにより、AIは物理的な身体を持たずとも、現実世界のフィードバックループを回すことが可能になりました。

### 3.2 Deterministic Infrastructure (決定論的インフラ)
**〜「幻覚」を排除する絶対的な基盤〜**
AIは環境要因によるエラーを「コードの誤り」と誤認（幻覚）しやすい傾向があります。本システムでは、DevContainerとCI環境の主要ツール(Pico SDK / ARM GCC / 検証入口)を揃え、環境差分を証拠ログとして残すことで、推測ではなく観測に基づいて切り分けられる状態を目指しています。

### 3.3 Recursive Engineering (再帰的エンジニアリング)
**〜環境自体を進化させる自己言及性〜**
本システムでは、成果物（アプリケーション）だけでなく、それを生み出す工場（環境）に対してもV字モデルを適用し、仕様化・テスト化しています。環境がコードと仕様で厳密に定義されているため、AIは「開発対象のプロダクト」だけでなく、**「自らが使う道具（環境）」そのものも自律的に修正・進化**させることができます。

---
*Documented by Antigravity*
