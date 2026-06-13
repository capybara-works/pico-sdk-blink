# テスト証拠ポリシー (Test Evidence Policy)

このプロジェクトでは、「AIが成功したと言うこと」ではなく、
**機械可読・再検証可能な証拠**に基づいて成功/失敗を判定します。

## 合格証拠として認めるもの

| 証拠 | 生成元 | 場所 |
|---|---|---|
| ビルドログ | `scripts/build.sh` / `scripts/build_firmware.sh` | `evidence/latest/build.log` |
| CTestログ | `scripts/build.sh` / `scripts/test_ctest.sh` | `evidence/latest/ctest.log` |
| Wokwiログ | `scripts/build.sh` / `scripts/test_wokwi.sh` / `scripts/record_wokwi_ci_result.sh` | `evidence/latest/wokwi.log` |
| 結果JSON (`*_result.json`) | 各 `scripts/*.sh` | `evidence/latest/` |
| UARTログ | `scripts/capture_uart.sh` / `scripts/run_hil.sh` | `evidence/latest/uart.log`, `hil.log` |
| GDBスナップショット | `scripts/gdb_snapshot.sh` | `evidence/latest/gdb_snapshot.json` |
| ロジックアナライザのデコード結果 | `scripts/capture_logic_i2c.sh` | `evidence/latest/logic_i2c_decode.txt` |
| 実取得スクリーンショット | 人間またはツールが実際に取得したもの | 取得経緯を明記して保存 |
| CI実行ログ | GitHub Actions | Actionsの実行ページ |
| CI証拠artifact | `scripts/fetch_ci_evidence.sh` | `artifacts/latest/evidence-with-wokwi/` |

## 証拠として認めないもの

- AIが生成したスクリーンショット風画像
- 実行していないのに「成功した」という説明
- ログやJSONに残っていない口頭(チャット内)説明のみの報告
- 推測だけの成功判定(「コード上は正しいはずなので成功」等)

## ステータスの意味

各 `*_result.json` の `status` は次のいずれかです。

- `pass` — 実際に実行され、期待結果が確認された
- `fail` — 実際に実行され、失敗した(ログに失敗理由が残る)
- `skip` — 前提(実機・ツール・設定)が無い、または `PICO_HARDWARE=1` 等の明示的許可が無いため実行されなかった
- `stub` — サンプル・代替データ・未有効化の代替経路による結果で、**実測値ではない**

**重要:** `skip` と `stub` は成功ではありません。報告時に「成功」と
言い換えてはいけません。

## 全体判定 (`verification.md` の Overall Status)

`scripts/summarize_evidence.py` が以下のルールで決定します。

- 1つでも `fail` → **fail**
- 全ステップが実行され全て `pass` → **pass**
- `pass` があるが、skip/stub/未実施が混在 → **partial**
- `pass` が1つもない → **skipped**

## 証拠の運用

- `evidence/latest/` は作業領域で、Git管理しない(`.gitkeep` のみコミット)。
- `artifacts/latest/` はCI artifactの取得先で、Git管理しない(`.gitkeep` のみコミット)。
  `scripts/fetch_ci_evidence.sh` は最新 successful run の `evidence-with-wokwi` を取得する。
- `scripts/verify_all.sh` は固定入口が生成する既知の証拠ファイルを初期化してから実行する。
  個別スクリプトを直接実行した場合は、そのスクリプトの証拠だけが更新される。
- 残したい代表例・学習用サンプルは `evidence/samples/` に小さく置いてコミットする。
- 証拠が不足している場合は、`verification.md` の Notes に不足内容が明記される。
  不足したまま成功判定をしてはいけない。

## 現在の自動検証カバレッジ

| 項目 | 現状 |
|---|---|
| Build | `scripts/build.sh` が `scripts/build_firmware.sh` を実行し、`build_result.json` を生成 |
| CTest | `scripts/build.sh` が `scripts/test_ctest.sh` を実行し、`ctest_result.json` を生成 |
| Wokwi | ローカル/Build jobでは `scripts/test_wokwi.sh` が `wokwi_result.json` を生成。CIの `test-on-wokwi` jobでは `scripts/record_wokwi_ci_result.sh` が action 結果を `evidence-with-wokwi` artifact に統合 |
| Flash / HIL / UART / GDB | `PICO_HARDWARE=1` のときのみ実機で実行 |
| HILシナリオ | 現状の共通stepは `wait-serial` |
| Logic Analyzer | `PICO_LOGIC_ANALYZER=1` かつ `sigrok-cli` 利用可能時のみ実測。それ以外はstub |
