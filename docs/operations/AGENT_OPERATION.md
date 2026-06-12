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

## 変更時のワークフロー

コード・ビルド設定・テストを変更したら、最低限以下を実行する。

```bash
scripts/build.sh                      # ビルド + ctest (+任意Wokwi)
scripts/run_hil.sh                    # 実機があればHIL、なければskip
python3 scripts/summarize_evidence.py # verification.md 生成
```

`evidence/latest/verification.md` の Overall Status と Notes を確認し、
skip / stub / fail をそのまま報告すること。skipを「成功」と言い換えてはいけない。

## 実機操作の安全

- フラッシュ・リセット・レジスタ読み出しは `scripts/` の入口経由で行う。
- 配線変更や電源操作はAIが指示だけで完結させず、人間が物理確認する。
- 実機が接続されていない場合、各スクリプトは明示的に skip を返す。
  skipを回避するための偽装(ダミーポート指定など)をしてはいけない。

## 任意シェル実行を前提にしない

- 検証フローは `scripts/` 配下の固定された入口スクリプトで完結させる。
- 将来のMCP化でも `run_shell(command)` のような任意コマンド実行ツールは
  提供しない([MCP_SETUP.md](../design/MCP_SETUP.md) 参照)。

## ローカル環境差分の扱い

- UARTポート、デバイスパス等は `config/hardware.local.yaml` または環境変数
  (`PICO_UART_PORT` 等)で渡す。スクリプトやコードに直書きしない。
- `hardware.local.yaml` と `.env*` はコミットしない(.gitignore済み)。
