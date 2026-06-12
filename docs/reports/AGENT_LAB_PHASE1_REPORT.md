# Phase 1 実装・検証レポート: 証拠ベース検証基盤

- **日付**: 2026-06-12
- **作業者**: AIエージェント (Claude) + 人間オペレーター
- **目的**: リポジトリを「PicoのLチカサンプル」から「Embedded AI Agent Lab」へ拡張する
  Phase 1 として、証拠ベース検証基盤を実装する

## 1. 実装内容

### 1.1 検証入口スクリプト (`scripts/`)

| スクリプト | 役割 | 実装状態 |
|---|---|---|
| `build.sh` | 既存 `build_and_test.sh` をラップし証拠保存 | 実装済み・実機確認済み |
| `flash.sh` | OpenOCD + Debug Probe で書き込み | 実装済み・実機確認済み |
| `run_hil.sh` | 既存 `hil_runner.py` をラップ | 実装済み・実機確認済み |
| `capture_uart.sh` | 既存 `uart_monitor.py` をラップ | 実装済み・実機確認済み |
| `gdb_snapshot.sh` | レジスタ + バックトレース取得 | 実装済み・実機確認済み |
| `capture_logic_i2c.sh` | sigrok-cli で I2C デコード | **スタブ**(機材未準備) |
| `summarize_evidence.py` | `verification.md` 生成 | 実装済み |
| `verify_all.sh` | 全ステップ一括実行 | 実装済み・実機確認済み |
| `common.sh` | 設定読み込み(`cfg_get`)・JSON出力共通化 | 実装済み |

設計原則: 既存資産(`build_and_test.sh` / `hil_runner.py` / `uart_monitor.py`)は
作り直さず薄くラップ。結果は `evidence/latest/` にログ + JSON
(`status: pass|fail|skip|stub`)で保存。環境依存値は
`config/hardware.local.yaml` / 環境変数に分離。

### 1.2 ドキュメント・設定

- `docs/operations/AGENT_OPERATION.md` — AI運用ルール(証拠なし成功判定の禁止)
- `docs/operations/TEST_EVIDENCE_POLICY.md` — 合格証拠の定義
- `docs/guides/HARDWARE_SETUP.md` — 接続・ツール・既知の落とし穴
- `docs/design/MCP_SETUP.md` / `tools/mcp_server/README.md` — 将来のMCP化設計メモ
- `docs/guides/LOGIC_ANALYZER_SETUP.md` — 将来のロジアナ運用方針
- `config/hardware.example.yaml` — 設定テンプレート
- `.gitignore` — local設定・証拠・ビルド成果物の除外

## 2. 検証結果(実測)

2026-06-12、実機(Pico + Debug Probe, UART `/dev/cu.usbmodem14402`)で
`scripts/verify_all.sh` を実行した結果:

| ステップ | 結果 | 根拠 |
|---|---|---|
| Build | pass | ctest 1/1 + Wokwiシナリオテスト成功 (`build.log`) |
| Flash | pass | OpenOCD Programming/Verify OK (`flash.log`) |
| HIL | pass | flash → `LED on`/`LED off` パターン照合成功 (`hil.log`) |
| UART | pass | 250ms周期で LED on/off を実測 (`uart.log`) |
| GDB | pass | `main() at blink.cpp:22` まで6フレームのバックトレース取得 (`gdb_snapshot.json`) |
| Logic Analyzer | stub | sigrok-cli 未インストール(機材未準備) |
| **Overall** | **partial** | ロジアナのみ未実測。`verification.md` 自動生成確認 |

## 3. 調査記録: GDBスナップショットがターゲットを停止させる問題

`gdb_snapshot.sh` の初版実装時、「スナップショット実行後にUART出力が止まる
(アプリが死ぬ)」事象が発生した。証拠に基づき切り分けた記録:

### 3.1 症状と切り分け

1. snapshot後の UART キャプチャが 0 行(直前は 5 秒で 20 行)
2. OpenOCD `targets` で core0 が `halted`、resume しても即
   `halted due to breakpoint`(PC=0x184、ブートROM領域)
3. **`hil_runner.py` の OpenOCD SIGTERM 終了を容疑として検証 → 無罪**
   (HIL実行後も core0 running・UART 14行を実測)
4. 健康なターゲットへの snapshot 単体実行で再現 → snapshot 自体が原因と確定
5. 素のOpenOCD halt では PC=0x10000d92(フラッシュ内)を正常取得
   → GDB attach 経路に固有の問題と確定
6. PC 0x10000d92 を `build/blink.S.dis` で逆引き → `sleep_ms` のタイマー
   ポーリングループ。PCが2回サンプリングで不動 + UART沈黙 →
   「タイマーが進んでいない」と判断

### 3.2 根本原因(2つ)

1. **GDB pipe 接続が core1 に接続されていた。**
   デフォルトの `target/rp2040.cfg`(2コア構成)では、GDB が halt した core1 が
   そのまま残ると、RP2040 の TIMER が **DBGPAUSE** 機構
   (いずれかのコアがデバッグhalt中はタイマー停止)により凍結する。
   その結果 core0 の `sleep_ms()` が `timer_time_reached` で永久スピンし、
   アプリが死んだように見える。
   観測した PC=0x138/0x184・SP=0x20041f00(初期値)・LR=0x15d は、
   core1 がブートROMの `wait_for_vector` で待機する正常な姿だった。
2. **GDB接続時のフラッシュプローブがターゲット上でアルゴリズムを実行する。**
   `gdb_memory_map` 有効(デフォルト)時、OpenOCD は GDB connect 時に
   フラッシュプローブをターゲットCPU上で実行し
   (`rp2040.cfg` 内コメント参照)、コアをブートROM内の
   ブレークポイントに置き去りにする。

### 3.3 対策(`scripts/gdb_snapshot.sh` に実装済み)

- `set USE_CORE 0` で core0 単独構成にして attach(core1 に触れない)
- `gdb_memory_map disable` でフラッシュプローブを抑止
- snapshot 後に core0 の状態を検証し、halted なら resume → だめなら
  `reset run` で自己修復。結果を `target_resumed` / `recovered_by_reset`
  として JSON に記録
- `pc_region` フィールド(bootrom / flash / sram)を追加し、
  AIの一次診断材料とした

### 3.4 復旧手順(同種事象に遭遇した場合)

```bash
# core1 halt によるタイマー凍結はリセット不要。core1 の resume のみで復旧する
openocd -f interface/cmsis-dap.cfg \
  -c "transport select swd; adapter speed 1000" -f target/rp2040.cfg \
  -c "init" -c "targets rp2040.core1" -c "resume" -c "shutdown"
```

詳細は `docs/guides/HARDWARE_SETUP.md` の「RP2040デバッグの既知の落とし穴」を参照。

## 4. 既存バグの修正

**`uart_monitor.py`: 0行キャプチャ時に exit 0(偽pass)するバグを修正。**
ポートエラー時・出力ゼロ時にパターン分析へ到達せず、そのまま正常終了していた。
今回の調査では「ターゲットが本当に停止している」ことの検出を妨げかけたため、
無出力を明示的に FAILED (exit 1) とした。証拠ベース検証の観点で重要な修正。
あわせて監視時間を第2引数で指定可能にした(後方互換)。

## 5. 未実装・次の課題

1. **ロジックアナライザ実機連携** — FX2LP系機材の準備待ち。
   `capture_logic_i2c.sh` の実行パスは実装済みで、sigrok-cli インストールと
   配線のみで stub → 実測に切り替わる
2. **MCPサーバー化** — `scripts/` 安定後(`docs/design/MCP_SETUP.md`)
3. **HILシナリオの拡充** — `expect-pin` の実機検証(`gpio_test.py` 統合)、
   複数サイクル・タイミング検証
4. **`hil_runner.py` の evidence 直接出力** — 現状はラッパー経由のログのみ
