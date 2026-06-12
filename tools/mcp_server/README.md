# MCP Server (Future Phase — Placeholder)

ここには将来、`scripts/` 配下の検証スクリプトを包む小さなSTDIO型MCPサーバーを置きます。
**現時点で実装はありません。** 設計方針は [docs/MCP_SETUP.md](../../docs/MCP_SETUP.md) を参照してください。

## 提供予定ツール

```text
build_project()                              -> scripts/build.sh
flash_firmware()                             -> scripts/flash.sh
run_hil_test()                               -> scripts/run_hil.sh
read_uart_log(duration_s)                    -> scripts/capture_uart.sh
gdb_snapshot()                               -> scripts/gdb_snapshot.sh
capture_logic_i2c(duration_ms, sample_rate)  -> scripts/capture_logic_i2c.sh
summarize_evidence()                         -> scripts/summarize_evidence.py
```

各ツールは対応するスクリプトを実行し、`evidence/latest/*_result.json` の内容を
そのまま返します。

## 制約

- **任意シェル実行ツール(`run_shell(command)`等)は実装しない。**
- パラメータは時間・サンプルレート等の限定された値のみ。パスやコマンド文字列を
  外部から注入できるインターフェースにしない。
- 実装着手の条件: `scripts/` 配下の各入口が実機環境で安定して動作していること。
