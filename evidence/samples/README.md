# 証拠サンプル一覧 (Evidence Samples)

ここにあるのは**代表サンプル(Record)**であり、最新の実行結果ではありません。
最新結果は各自が `scripts/verify_all.sh` を実行して `evidence/latest/` に生成してください。

**重要:** サンプルごとに「実機実測」か「合成(教材用)」か「stub」かを必ず区別してください。
stub と pass を混同してはいけません([../../docs/operations/TEST_EVIDENCE_POLICY.md](../../docs/operations/TEST_EVIDENCE_POLICY.md))。

## Phase 1 代表証拠(実機実測, 2026-06-12)

実機 (Raspberry Pi Pico + Debug Probe) で `PICO_HARDWARE=1 scripts/verify_all.sh` を
実行した実測結果のスナップショット。詳細は
[../../docs/reports/AGENT_LAB_PHASE1_REPORT.md](../../docs/reports/AGENT_LAB_PHASE1_REPORT.md)。

| ファイル | 来歴 | 内容 |
|---|---|---|
| `verification_phase1_sample.md` | **実機実測** | Build/Flash/HIL/UART/GDB = pass、Logic Analyzer = stub、Overall = **partial** |
| `gdb_snapshot_phase1_sample.json` | **実機実測** | 動作中ファームウェアの実レジスタ値 + `main()` までのバックトレース |
| `uart_phase1_sample.log` | **実機実測** | 250ms周期の `LED on`/`LED off` 実キャプチャ(パターン検証pass) |

## 教材・解析練習用サンプル(合成)

実機がなくてもAIや人間がログ解析・原因推定を練習できるように作った**架空の例**です。

| ファイル | 来歴 | 内容 |
|---|---|---|
| `build_pass_sample.log` | 合成 | 正常ビルドのログ例 |
| `build_fail_sample.log` | 合成 | コンパイルエラー(typo)のログ例 |
| `uart_pass_sample.log` | 合成 | UARTパターン検証passのログ例 |
| `i2c_nack_decode_sample.txt` | 合成 | I2C NACK(デバイス無応答)のデコード例。**stub実行時にこのファイルがコピーされる** |
| `verification_sample.md` | 合成 | verification.md の形式例 |

## 運用ルール

- 大きな生ログ・波形ファイル(`.sr` / `.csv`)はここに置かない(.gitignore済み)
- 新しい代表証拠を追加するときは、この README に来歴(実測/合成/stub)を必ず追記する
