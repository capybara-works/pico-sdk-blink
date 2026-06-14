# 04. 検証フロー (UML: シーケンス図)

`verify_all.sh` を1回実行したとき、**時間に沿って何が起きるか**を示します。
安全ゲートによる分岐(実機を触る/触らない)が、この基盤の核心です。

```mermaid
sequenceDiagram
    actor Dev as 人間/AI
    participant VA as verify_all.sh
    participant B as build.sh
    participant HW as flash/hil/uart/gdb
    participant LG as logic analyzer scripts
    participant EV as evidence/latest
    participant SM as summarize_evidence.py

    Dev->>VA: 実行 (PICO_HARDWARE? / PICO_LOGIC_UART? / PICO_LOGIC_I2C?)
    VA->>EV: reset_evidence_dir(既知の生成物を掃除)
    VA->>B: build_firmware + ctest + 任意wokwi
    Note over B: WokwiはPICO_BUILD_DIR配下の<br/>blink.elfと既定scenarioを明示
    B->>EV: build / ctest / wokwi _result.json<br/>(artifact path + sha256)

    alt build 失敗
        VA->>SM: 要約のみ生成
        Note over VA,HW: 実機ステップは試行しない<br/>(古いELFを焼くと誤った証拠になる)
    else build 成功
        VA->>HW: flash → hil → uart → gdb
        alt PICO_HARDWARE=1
            HW->>EV: 実測結果 (pass / fail)
        else 未設定(既定)
            HW->>EV: skip を記録
        end
        VA->>LG: capture_logic_uart → capture_logic_i2c
        alt PICO_LOGIC_UART=1 / PICO_LOGIC_I2C=1 / PICO_LOGIC_ANALYZER=1
            LG->>EV: 実測デコード (pass / fail)
        else 未設定(既定)
            LG->>EV: stub(サンプルをコピー)
        end
    end

    VA->>SM: 集約
    SM->>EV: verification.md (Overall Status)
    EV-->>Dev: 証拠に基づく裁可
```

## 読み方

- **既定(ゲート未設定)では、ハードウェアには一切触れません**。flash/hil/uart/gdb は `skip`、ロジックアナライザは `stub` を**証拠として**記録します。これらは「成功」ではありません。
- `PICO_HARDWARE=1` を**人間が明示的に**付けたときだけ実機を操作します。AIがこのゲートを勝手に有効化・回避することは禁止です([../operations/AGENT_OPERATION.md](../operations/AGENT_OPERATION.md))。
- ロジックアナライザは `PICO_LOGIC_UART=1` / `PICO_LOGIC_I2C=1` で個別に実測します。`PICO_LOGIC_ANALYZER=1` は全captureを有効化する互換スイッチです。
- **ビルド失敗は早期打ち切り**。古いファームウェアを焼いて「動いているように見える」誤証拠を避ける設計です。
- **Wokwiは対象ELFとscenarioを明示**します。Docker経路では `build-docker/blink.elf`、ホスト経路では `build/blink.elf` を使い、既定では `blink_i2c.test.yaml` でI2Cスキャン + UARTログを検証します。`*_result.json` の `artifacts` でパスとhashを確認できます。
- 最終的な裁可は `verification.md` の要約ではなく、**一次証拠(`*_result.json` と各ログ)**に基づいて行います。

## 判定の決まり方

各ステップの status(pass/fail/skip/stub)から Overall がどう決まるかは
[05_evidence_states.md](05_evidence_states.md) を参照してください。

## Source of Truth

- 実行順: [../../scripts/verify_all.sh](../../scripts/verify_all.sh)
- ゲート実装: [../../scripts/common.sh](../../scripts/common.sh) の `hardware_gate` / `logic_capture_enabled`
