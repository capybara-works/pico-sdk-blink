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

## 計測・診断結果の解釈ディシプリン

実機の計測値から原因を結論づける際、AIは以下を守る。
(背景: GP29/VSYS測定で、測定手順のバグを「基板のVSYS/3分圧欠落・クローン」と誤判定し、
誤結論を docs/memory/push まで伝播させた事故がある。詳細手順は
[../guides/MEASUREMENT_PRACTICES.md](../guides/MEASUREMENT_PRACTICES.md)。)

1. **反証データを先に列挙する。** 結論に反するデータ点をまず挙げ、それでも結論が成立するか確認する。
   **反証データを説明できない結論は採用しない。**(例: `gp29 nopull raw=2104`≒VSYS5.1V を
   説明できない限り「GP29フローティング」とは言えない。)
2. **事実・推測・未確認・結論を分離して述べる。** 「ログ上こう出ている(事実)/この可能性(推測)/
   まだ断定できない(未確認)/現時点の結論」を混ぜない。弱気にするのではなく層を分ける。
3. **生値・換算値・物理値を名前で分ける。** ログ名・変数名で `*_raw` / `*_adc_mv`(入力電圧) /
   物理推定値(例 `vsys_est_mv`)を区別する。`vsys_mv` のような多義的な名前は使わない。
4. **ハード不良・クローン差異・基板欠落・部品実装漏れを主因とするのは最後。**
   先に (1)仕様上の期待値 (2)測定手順の妥当性 (3)換算式 (4)複数回の再測定 (5)反証データの不在
   を確認してから。これらが揃わない限り「怪しいからハード不良」と結論しない。
5. **伝播ゲート: 未確認の診断結論を永続記録へ断定形で書かない。**
   committed docs / memory / README / report へは、確認測定または人間承認が済んだ結論のみ断定形で残す。
   未確認は「暫定/仮説」と明記する。push前に事実/推測/未確認を分離する。
   **特に memory は以後のAI判断を汚染するため docs より危険。**
6. **後戻りコストが高い結論はセカンドオピニオンを推奨。** ハード不良・基板/クローン差異・部品欠落・
   永続記録への反映など取り消しにくい結論の前には、人間または別モデルの確認を挟む(常時ではなく条件付き)。
7. **誤診断が判明したら回収する。** (a)関連docsの誤記を修正 (b)memoryの誤結論を訂正/削除
   (c)commit履歴上の該当箇所を訂正コミットで追跡(履歴改変はしない) (d)訂正理由を短く記録
   (e)今後の判定基準を追記。判明時は誤結論の文言を横断検索(`git grep` / memory)して残存を潰す。

## 任意シェル実行を前提にしない

- 検証フローは `scripts/` 配下の固定された入口スクリプトで完結させる。
- 将来のMCP化でも `run_shell(command)` のような任意コマンド実行ツールは
  提供しない([MCP_SETUP.md](../design/MCP_SETUP.md) 参照)。

## ローカル環境差分の扱い

- UARTポート、デバイスパス等は `config/hardware.local.yaml` または環境変数
  (`PICO_UART_PORT` 等)で渡す。スクリプトやコードに直書きしない。
- `hardware.local.yaml` と `.env*` はコミットしない(.gitignore済み)。
