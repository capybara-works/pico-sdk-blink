# AIエージェント運用ルール (Agent Operation Rules)

このリポジトリは「Embedded AI Agent Lab」です。AIエージェントがコードを変更し、
ビルド・シミュレーション・実機観測で検証する閉ループを扱います。
AIエージェント(および人間)は以下のルールに従ってください。

## 基本原則: 証拠なしに成功と言わない

1. **AIは証拠なしに成功判定してはいけない。**
   成功/失敗の判定は、必ず `evidence/latest/` 配下のログ・JSON・デコード結果・
   実取得スクリーンショットに基づくこと。何が証拠として認められるかは
   [TEST_EVIDENCE_POLICY.md](TEST_EVIDENCE_POLICY.md) を参照。

2. **生成スクリーンショットや推測を証拠扱いしてはいけない。**
   AIが生成した画像、「おそらく動くはず」という推測、実行していない手順の説明は
   証拠ではない。

3. **判断の前にログとJSONを読む。**
   `evidence/latest/*_result.json` の `status` フィールドと、対応するログ本文を
   確認してから結論を出すこと。`verification.md` は要約であり、一次証拠ではない。
   Build/Wokwiの結果JSONに `artifacts` が含まれる場合は、対象パスとhashが
   意図したbuild directory (`build/`, `build-docker/` 等) を指しているかも確認する。

## 変更時のワークフロー

コード・ビルド設定・テストを変更したら、最低限以下を実行する。

```bash
scripts/build.sh                      # build_firmware + ctest (+任意Wokwi)
scripts/verify_all.sh                 # 全ループ (実機系はゲートによりskip)
python3 scripts/summarize_evidence.py # verification.md 生成
```

`scripts/verify_all.sh` は固定入口が生成する既知の証拠ファイルを初期化してから実行する。
個別スクリプトを直接実行した場合は、そのスクリプトの証拠だけが更新される。
`scripts/build.sh` は `build_result.json` / `ctest_result.json` / `wokwi_result.json` を個別に生成する。
CIのWokwi統合済み証拠を確認する場合は `scripts/fetch_ci_evidence.sh` で
`artifacts/latest/evidence-with-wokwi/<run_id>/` に取得し、`verification.md` と
`wokwi_result.json` を読む。
CIのfirmware payloadをローカル成果物と比較する場合は `scripts/fetch_ci_firmware.sh`
で `artifacts/latest/firmware/<run_id>/` に取得し、`blink.uf2` と `blink.bin` のhashを比較する。
GitHub CLIを手動で使う場合は、複数remoteにより `upstream` 側へ推測されることが
あるため、`-R capybara-works/pico-sdk-blink` または
`GH_REPO=capybara-works/pico-sdk-blink` を明示する。

`evidence/latest/verification.md` の Overall Status と Notes を確認し、
skip / stub / fail をそのまま報告すること。skipを「成功」と言い換えてはいけない。

## 実機操作の安全

- **実機操作(flash/HIL/UART/GDB)は `PICO_HARDWARE=1` が明示された場合のみ実行される。**
  未設定なら各スクリプトは skip を記録して終了する。AIがこのゲートを勝手に
  有効化したり回避したりしてはいけない(有効化は人間の判断)。
- **ロジックアナライザ実測は `PICO_LOGIC_UART=1` / `PICO_LOGIC_I2C=1`
  または全capture用の `PICO_LOGIC_ANALYZER=1` が明示された場合のみ実行される。**
  未設定なら stub(サンプルデコード)を記録する。個別ゲートが明示されている場合は
  `PICO_LOGIC_ANALYZER` より優先される。
- フラッシュ・リセット・レジスタ読み出しは `scripts/` の入口経由で行う。
- 配線変更や電源操作はAIが指示だけで完結させず、人間が物理確認する。
- ゲート未許可、必要ツール未導入、ポート未設定など実行前提がない場合は skip。
  `PICO_HARDWARE=1` で実行を開始した後の接続失敗・書き込み失敗・パターン不一致は fail。
  skipを回避するための偽装(ダミーポート指定など)をしてはいけない。

## 任意シェル実行を前提にしない

- 検証フローは `scripts/` 配下の固定された入口スクリプトで完結させる。
- 将来のMCP化でも `run_shell(command)` のような任意コマンド実行ツールは
  提供しない([MCP_SETUP.md](../design/MCP_SETUP.md) 参照)。

## ローカル環境差分の扱い

- UARTポート、デバイスパス等は `config/hardware.local.yaml` または環境変数
  (`PICO_UART_PORT` 等)で渡す。スクリプトやコードに直書きしない。
- `hardware.local.yaml` と `.env*` はコミットしない(.gitignore済み)。
