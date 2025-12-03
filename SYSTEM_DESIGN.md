# System Design Document: AI-Driven Embedded Platform

## 1. Project Structure

本プロジェクトのディレクトリ構成と各ファイルの役割は以下の通りです。

```text
.
├── .github/workflows/
│   └── ci.yml              # GitHub Actions CIワークフロー定義 (Build & Test)
├── .vscode/                # VS Code用設定ファイル (Extensions, Settings)
├── build/                  # ビルド成果物出力ディレクトリ (Git除外)
├── docs/                   # [Doc] V字モデルドキュメント群
│   ├── v_model/            # [Product] アプリケーション仕様書
│   └── v_model_environment/# [Factory] 環境仕様書
├── blink.cpp               # [Main] アプリケーションのエントリーポイント (Sample)
├── blink.test.yaml         # [Test] Wokwiオートメーション用テストシナリオ定義
├── build_and_test.sh       # [Script] ローカル/CI兼用の統合ビルド・テストスクリプト
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
    *   **重要性**: これが物理的な回路図の代わりとなり、シミュレーションの正当性を保証します。

*   **`blink.test.yaml`**:
    *   **役割**: 「1秒間シミュレーションを実行し、ピンの状態を監視する」といったテストシナリオを記述。
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
| **パイプライン** | `build_and_test.sh`<br>`.github/workflows/ci.yml` | ローカルとCIで**完全に等価な**検証プロセスを保証する仕組み。 |

### 2.2 AI-Driven CI/CD Workflow
開発者がコードを書き、Gitにプッシュする裏側で、以下のプロセスが自動的に回っています。

1.  **Push**: 変更をGitHubに送信。
2.  **CI Trigger**: GitHub Actionsが起動。
3.  **Reproduce**: クラウド上でクリーンな環境を一から構築。
4.  **Build & Test**: ローカルと同じスクリプトでビルドし、サイズチェック等のテストを実行。
5.  **Feedback**: 結果がバッジとしてREADMEに表示される。

この「守られた環境」があるからこそ、AIに大胆なコード修正を指示しても、システムが壊れることを恐れずに開発を進められます。

## 3. Core Philosophy: The Agentic Embedded Platform

本システムは、単なる開発テンプレートではなく、**「AIエージェントが物理世界（Embedded System）を自律的にハックするためのプラットフォーム」**として設計されています。

### 3.1 Virtual Embodiment (身体性の仮想化)
**〜AIに「目」と「指」を与える〜**
従来のLLMはテキストしか扱えず、物理的な現象を観測できませんでした。本システムでは、Wokwiシミュレータとテストスクリプトの統合により、電圧変化やUART信号といった物理現象を**「テキストベースの論理的事実」**に変換しています。これにより、AIは物理的な身体を持たずとも、現実世界のフィードバックループを回すことが可能になりました。

### 3.2 Deterministic Infrastructure (決定論的インフラ)
**〜「幻覚」を排除する絶対的な基盤〜**
AIは環境要因によるエラーを「コードの誤り」と誤認（幻覚）しやすい傾向があります。本システムでは、DevcontainerとCI環境をバイナリレベルで完全同期させることで、**「環境の不確実性」をゼロ**にしました。「動かないなら、それは100%コードのせいである」という決定論的な世界を提供することで、AIの推論精度を最大化させています。

### 3.3 Recursive Engineering (再帰的エンジニアリング)
**〜環境自体を進化させる自己言及性〜**
本システムでは、成果物（アプリケーション）だけでなく、それを生み出す工場（環境）に対してもV字モデルを適用し、仕様化・テスト化しています。環境がコードと仕様で厳密に定義されているため、AIは「開発対象のプロダクト」だけでなく、**「自らが使う道具（環境）」そのものも自律的に修正・進化**させることができます。

---
*Documented by Antigravity*
