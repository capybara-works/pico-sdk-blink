# アーキテクチャ図 (Architecture Views)

この基盤(Embedded AI Agent Lab)を**段階的なズーム**で理解するためのビュー集です。
題材ファームウェア(Lチカ)ではなく、**検証ループという仕組みそのもの**を対象に描いています。

記法は **C4モデル**(System Context → Container → Component)を背骨に、
振る舞いを **UML**(シーケンス図・ステートマシン図)で補います。すべて **Mermaid** で
記述しており、GitHub / VS Code でそのまま描画され、テキストとして差分が取れます。

## ビュー一覧

| ファイル | 答える問い | 記法 |
|---|---|---|
| [01_context.md](01_context.md) | このラボは外から見て誰/何と関わるか | C4 System Context |
| [02_containers.md](02_containers.md) | 中にどんな主要構成要素があるか | C4 Container |
| [03_components_scripts.md](03_components_scripts.md) | `scripts/` の内部構造と依存はどうなっているか | C4 Component |
| [04_verification_flow.md](04_verification_flow.md) | 1回の検証実行はどう流れるか | UML シーケンス図 |
| [05_evidence_states.md](05_evidence_states.md) | 成否(pass/fail/skip/stub/partial)はどう決まるか | UML ステートマシン図 |
| [06_deployment.md](06_deployment.md) | どの環境でどう動き、証拠がどこへ流れるか | デプロイ図 |

**おすすめの読む順**: 01 → 02 で全体像、03 で `scripts/` の中身、04 → 05 で動きと判定、
06 で環境配置。「全貌が掴めない」場合は 01 と 04 の2枚だけでも骨格が見えます。

## このビュー群の位置づけと維持方針

- 分類は **Living**(構造やフローが変わったら更新)。[../README.md](../README.md) の分類表に登録済み。
- 各図は**一次情報(実ファイル)を Source of Truth とし**、図はその要約です。各ビューの末尾に
  対応する実ファイルを明記しているので、疑わしいときは必ず実物を確認してください。
- C4 の Context / Container 層は粒度が粗く**変化が遅い**ため、腐りにくい構成です。
  細粒度の 03(Component)は `scripts/` を増減したときに見直します。
- 「今この瞬間の検証状態」を知りたい場合は、図ではなく
  `evidence/latest/verification.md`(`summarize_evidence.py` が生成・Git管理外)を見ます。
  05 はその**判定モデル**を静的に説明したものです。
