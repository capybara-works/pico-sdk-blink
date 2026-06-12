# Embedded AI Agent Lab — エージェント向けガイド

Raspberry Pi Pico (RP2040) を題材にした Embedded AI Agent Lab。
AI生成コードをビルド → シミュレーション → 実機 → 観測 → 証拠保存の
閉ループで検証する。詳細は [README.md](README.md)。

## 絶対ルール

- **証拠なしに成功と言わない。** 成功判定は `evidence/latest/` のログ・JSONのみに基づく。
  skip / stub は成功ではない。詳細: [docs/operations/AGENT_OPERATION.md](docs/operations/AGENT_OPERATION.md)
- 変更後は必ず検証スクリプトを実行し、`evidence/latest/verification.md` を確認する。
- ローカル環境依存値(UARTポート等)はコードに直書きしない。
  `config/hardware.local.yaml` または環境変数 (`PICO_UART_PORT`) を使う。

## 主要コマンド

```bash
scripts/verify_all.sh                  # 検証ループ一括 (build→flash→HIL→UART→GDB→ロジアナ→summary)
scripts/build.sh                       # ビルド + ctest + 任意Wokwi
scripts/run_hil.sh                     # 実機E2E (実機なしなら自動skip)
python3 scripts/summarize_evidence.py  # evidence/latest/verification.md 生成
```

実機ステップは未設定環境では明示的に skip を返す(偽装してはいけない)。

## 構成の要点

- `scripts/` — 検証入口(各々がログ+JSONを `evidence/latest/` に保存)
- `tools/hil/` — HIL実装本体 (hil_runner.py / uart_monitor.py / gpio_test.py)
- `docs/README.md` — 文書マップ。規程は `docs/operations/`、手順は `docs/guides/`、
  調査記録は `docs/reports/`(書き換え禁止のRecord)
- 実機デバッグで詰まったら [docs/guides/HARDWARE_SETUP.md](docs/guides/HARDWARE_SETUP.md) の
  「RP2040デバッグの既知の落とし穴」(DBGPAUSEタイマー凍結・flash probe問題)を必ず参照

## 禁止事項

- 任意シェル実行をAIに公開するツールの作成 ([docs/design/MCP_SETUP.md](docs/design/MCP_SETUP.md))
- `docs/reports/` 配下の過去レポートの書き換え
- `evidence/latest/` の生成物・`config/hardware.local.yaml`・`.env*` のコミット
