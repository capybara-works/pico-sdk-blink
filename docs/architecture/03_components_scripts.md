# 03. コンポーネント図 (C4: Component — `scripts/`)

最も内側のズームで、**`scripts/` の中身**を分解します。この基盤の心臓部であり、
各入口がどう連なり、共通ヘルパーと証拠ストアにどう依存するかを示します。

```mermaid
flowchart TB
    va["verify_all.sh<br/>オーケストレータ"]

    subgraph soft["ビルド/ソフト検証 (常に実行)"]
        b["build.sh"]
        bf["build_firmware.sh<br/>cmake configure + build"]
        ct["test_ctest.sh<br/>size_check"]
        tw["test_wokwi.sh<br/>PICO_BUILD_DIRのELFを--elf指定<br/>トークン無ければskip"]
    end

    subgraph hwp["実機/観測 (PICO_HARDWARE=1 のとき実測)"]
        fl["flash.sh"]
        hl["run_hil.sh → hil_runner.py"]
        ua["capture_uart.sh → uart_monitor.py"]
        gd["gdb_snapshot.sh"]
    end

    lgu["capture_logic_uart.sh<br/>PICO_LOGIC_ANALYZER=1 でUART実測 / 否ならstub"]
    lgi["capture_logic_i2c.sh<br/>PICO_LOGIC_ANALYZER=1 でI2C実測 / 否ならstub"]
    sm["summarize_evidence.py<br/>→ verification.md"]
    common["common.sh<br/>hardware_gate / write_result_json<br/>cfg_get / reset_evidence_dir<br/>build_dir / artifact_metadata_json / target_elf_path"]
    ev[("evidence/latest/<br/>*_result.json + *.log")]

    va --> b
    b --> bf --> ct --> tw
    va --> fl
    fl --> hl --> ua --> gd
    va --> lgu --> lgi
    va --> sm

    b -. uses .-> common
    fl -. uses .-> common
    hl -. uses .-> common
    ua -. uses .-> common
    gd -. uses .-> common
    lgu -. uses .-> common
    lgi -. uses .-> common

    b --> ev
    fl --> ev
    hl --> ev
    ua --> ev
    gd --> ev
    lgu --> ev
    lgi --> ev
    ev --> sm

    subgraph cii["CI証拠連携 (手動/CI)"]
        rec["record_wokwi_ci_result.sh<br/>action結果を証拠化"]
        fe["fetch_ci_evidence.sh<br/>evidence-with-wokwi 取得"]
        ff["fetch_ci_firmware.sh<br/>firmware取得 + hash"]
    end
```

## 読み方

- **`verify_all.sh` が全体の指揮者**。`build.sh` が失敗したら実機ステップは試行せず要約だけ生成します(古いELFを焼かないため)。
- **`common.sh` が証拠付き入口の土台**。安全ゲート(`hardware_gate`)、結果JSONの書き出し(`write_result_json`)、設定読み込み(`cfg_get`)、証拠掃除(`reset_evidence_dir`)、ビルド成果物解決(`build_dir` / `target_elf_path`)、成果物ハッシュ(`artifact_metadata_json`)を提供します。
- **証拠付き入口は `evidence/latest/` に「ログ+結果JSON」を残し**、`summarize_evidence.py` がそれを集約して `verification.md` を作ります。低レベル部品(`build_firmware.sh`, `test_ctest.sh`, `test_wokwi.sh`)を直接実行した場合は、呼び出し元による証拠化は行われません。
- **CI証拠連携の3本**は通常ループの外側で、CIが生成した証拠/ファームウェアを取得・記録するためのものです。

## 注意(実装の現状メモ)

- UART読み取りは `uart_monitor.py`(`capture_uart.sh` 用)と `hil_runner.py` 内 `UARTMonitor`(`run_hil.sh` 用)の**2実装**があり、内容が分岐しています。共通化が望ましい箇所です。
- `gpio_test.py` は手動/調査用で、この自動ループからは呼ばれません。

## Source of Truth

- 各スクリプト本体: [../../scripts/](../../scripts/)
- 実機ツール本体: [../../tools/hil/](../../tools/hil/)
- 動きの時系列は [04_verification_flow.md](04_verification_flow.md) へ
