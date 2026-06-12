# MCP化方針 (MCP Setup — Design Memo)

MCP(Model Context Protocol)化は**将来フェーズ**です。本書は設計メモであり、
現時点でMCPサーバーの実装はありません。スタブの置き場所は
[tools/mcp_server/README.md](../tools/mcp_server/README.md) を参照してください。

## 方針

- MCPサーバーは**ローカルで動く小さなツールサーバー/プロセス**として扱う。
- まずは **STDIO型**(クライアントが子プロセスとして起動)を想定する。
  HTTP/SSE化は必要になってから検討する。
- **既存の `scripts/` 配下のスクリプトが安定してから**、それらを薄く包む形で
  MCPツール化する。ロジックはスクリプト側に置き、MCP層は入出力の変換だけを行う。
- ツールの結果は、スクリプトが書き出す `evidence/latest/*_result.json` を
  そのまま返す。MCP層で結果を加工・解釈しない。

## 提供予定のツール

| MCPツール | 包むスクリプト |
|---|---|
| `build_project()` | `scripts/build.sh` |
| `flash_firmware()` | `scripts/flash.sh` |
| `run_hil_test()` | `scripts/run_hil.sh` |
| `read_uart_log(duration_s)` | `scripts/capture_uart.sh` |
| `gdb_snapshot()` | `scripts/gdb_snapshot.sh` |
| `capture_logic_i2c(duration_ms, sample_rate)` | `scripts/capture_logic_i2c.sh` |
| `summarize_evidence()` | `scripts/summarize_evidence.py` |

## 禁止事項

**任意シェルコマンドを実行するツールは公開しない。**

```text
禁止: run_shell(command: string)
```

公開するのは、上の表のような**固定された安全な操作**だけです。
パラメータも列挙可能な値(時間、サンプルレート等)に限定し、
パスやコマンド文字列を外部から注入できる設計にしません。
