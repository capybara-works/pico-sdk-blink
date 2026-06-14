# ドキュメントマップ (Documentation Map)

このディレクトリの文書は、**種類**と**更新方針**で分類されています。

## 分類と更新方針

| ディレクトリ | 種類 | 更新方針 |
|---|---|---|
| `operations/` | 運用規程 (Rules) | **Living** — 常に現状を反映。運用が変わったら即更新する |
| `guides/` | セットアップ・手順書 (Guides) | **Living** — 常に現状を反映。手順が変わったら即更新する |
| `design/` | 設計メモ (Design Memos) | **Living** — 方針変更時に更新。実装済みになったらガイドへ昇格 |
| `reports/` | 調査・検証レポート (Reports) | **Record** — その時点の記録。原則として後から書き換えない |
| `architecture/` | アーキテクチャ図 (Views) | **Living** — 構造/フロー変更時に更新。C4+UMLをMermaidで保持 |
| `v_model/` | アプリ仕様書 (V字モデル) | Living — 仕様変更時に更新 |
| `v_model_environment/` | 環境仕様書 (V字モデル) | Living — 環境変更時に更新 |

**Record(記録)文書の扱い:** `reports/` は実施日時点のスナップショットであり、
ファイルパスやツール構成が現在と異なっていてもそのまま残します。
現在の正しい手順は常に `guides/` と `operations/` を参照してください。

**読み方の優先順位:** 現在の運用判断は `operations/` → `guides/` →
リポジトリ直下の概要文書 → `v_model/` / `v_model_environment/` の順に確認します。
`reports/` と現在の実装・Living文書が矛盾して見える場合は、`reports/` を
当時の記録として扱い、Living文書を優先してください。

**新しい文書の置き場所:**
- 調査・検証を実施したら → `reports/` に日付入りでレポートを追加
- 運用ルールを追加・変更したら → `operations/` を更新
- 手順が変わったら → `guides/` を更新(レポートは書き換えない)
- テストシナリオやHIL対応stepが変わったら → `CONTRIBUTING.md` と
  `v_model/04_test_specification.md` を更新
- 回路/ピン/シミュレータ構成が変わったら → `diagram.json` と
  `v_model/02_basic_design.md` / `v_model/03_detailed_design.md` を同期
- 検証入口や証拠ファイルの扱いが変わったら → `operations/` と `README.md` を同期

## 文書一覧

### operations/ — 運用規程

| 文書 | 内容 |
|---|---|
| [AGENT_OPERATION.md](operations/AGENT_OPERATION.md) | AIエージェントの運用ルール(証拠なし成功判定の禁止 等) |
| [TEST_EVIDENCE_POLICY.md](operations/TEST_EVIDENCE_POLICY.md) | 何を合格証拠と認めるか、status の意味、全体判定ルール |

### guides/ — セットアップ・手順書

| 文書 | 内容 |
|---|---|
| [SETUP_GUIDE.md](guides/SETUP_GUIDE.md) | 開発環境構築 (DevContainer / Docker / ローカル) |
| [HARDWARE_SETUP.md](guides/HARDWARE_SETUP.md) | Pico / Debug Probe / UART / SWD 接続、RP2040デバッグの既知の落とし穴 |
| [LOGIC_ANALYZER_SETUP.md](guides/LOGIC_ANALYZER_SETUP.md) | FX2LP系ロジックアナライザ + sigrok (将来フェーズ) |
| [DEBUGGING_AND_ANALYSIS.md](guides/DEBUGGING_AND_ANALYSIS.md) | 静的解析 (blink.S.dis) と実行時解析 (GDBスナップショット) |

### design/ — 設計メモ

| 文書 | 内容 |
|---|---|
| [MCP_SETUP.md](design/MCP_SETUP.md) | MCPサーバー化の方針 (将来フェーズ、任意シェル実行は提供しない) |

### architecture/ — アーキテクチャ図 (Views)

C4モデル(Context/Container/Component)+ UML(シーケンス/ステート)を Mermaid で記述した、
**この開発基盤そのものを理解するための図集**。題材ファームウェアではなく検証ループを対象とする。

| 文書 | 内容 |
|---|---|
| [architecture/README.md](architecture/README.md) | ビュー索引(どの図が何の問いに答えるか) |
| [architecture/01_context.md](architecture/01_context.md) | C4 System Context — 外部との関わり |
| [architecture/02_containers.md](architecture/02_containers.md) | C4 Container — 主要構成要素 |
| [architecture/03_components_scripts.md](architecture/03_components_scripts.md) | C4 Component — `scripts/` の内部 |
| [architecture/04_verification_flow.md](architecture/04_verification_flow.md) | UML シーケンス — 1回の検証実行の流れ |
| [architecture/05_evidence_states.md](architecture/05_evidence_states.md) | UML ステートマシン — 証拠ステータスと全体判定 |
| [architecture/06_deployment.md](architecture/06_deployment.md) | デプロイ — ローカル/Docker/CI/実機の配置 |

### reports/ — 調査・検証レポート (Record)

| 文書 | 日付 | 内容 |
|---|---|---|
| [AGENT_LAB_PHASE1_REPORT.md](reports/AGENT_LAB_PHASE1_REPORT.md) | 2026-06-12 | Phase 1 証拠基盤の実装・実機検証・GDB/DBGPAUSE調査記録 |
| [PHYSICAL_LAYER_ANALYSIS.md](reports/PHYSICAL_LAYER_ANALYSIS.md) | 2025-12 | 物理層解析 |
| [HARDWARE_INTEGRATION_TEST_REPORT.md](reports/HARDWARE_INTEGRATION_TEST_REPORT.md) | 2025-12 | Phase 0.8 実機統合テスト |
| [HIL_RESEARCH_REPORT.md](reports/HIL_RESEARCH_REPORT.md) | 2025-12 | HIL構築調査 (配線情報含む) |
| [SYSTEM_REPORT.md](reports/SYSTEM_REPORT.md) | 2025-12 | システムレポート |

### リポジトリ直下の文書

| 文書 | 内容 |
|---|---|
| [../README.md](../README.md) | プロジェクト概要・検証ループの使い方 |
| [../SYSTEM_DESIGN.md](../SYSTEM_DESIGN.md) | プラットフォーム設計書 (ディレクトリ構成・アーキテクチャ) |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | 開発ワークフロー (Vibe Coding + 証拠ベース検証) |
| [../CLAUDE.md](../CLAUDE.md) | AIエージェント向けエントリポイント |
