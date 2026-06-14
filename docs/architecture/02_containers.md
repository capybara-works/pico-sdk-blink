# 02. コンテナ図 (C4: Container)

ラボの**一段内側**です。リポジトリを構成する主要な「箱」(コンテナ=独立して動く/管理される単位)と、
その間のデータの流れを示します。ファイル単位ではなく、役割のまとまりで見ます。

```mermaid
flowchart TB
    actor["人間 / AIエージェント"]

    subgraph lab["Embedded AI Agent Lab"]
        direction TB
        scripts["scripts/<br/>証拠付き入口 + 低レベル部品<br/>build/flash/hil/uart/gdb/logic/summarize"]
        hil["tools/hil/<br/>hil_runner.py / uart_monitor.py / gpio_test.py"]
        cfg["config/<br/>hardware.local.yaml ← example<br/>(ローカル環境値・Git管理外)"]
        src["ファームウェア定義<br/>blink.cpp / CMakeLists.txt<br/>diagram.json<br/>blink.test.yaml / blink_i2c.test.yaml"]
        build["ビルド出力<br/>build/ ・ build-docker/ (Git管理外)"]
        ev["evidence/<br/>latest/(作業・Git管理外)<br/>samples/(教材・Git管理)"]
        art["artifacts/latest/<br/>CI取得物 (Git管理外)"]
        docs["docs/<br/>operations/guides/design<br/>reports/v_model/architecture"]
        ciw[".github/workflows/<br/>ci.yml ・ devcontainer-image.yml"]
    end

    extWokwi["Wokwi"]
    extHw["Pico + Debug Probe"]
    extCI["GitHub Actions / GHCR"]

    actor -->|"固定入口を呼ぶ"| scripts
    scripts -->|"PICO_BUILD_DIRへビルド"| src
    src --> build
    scripts -->|"実機操作を委譲"| hil
    scripts -->|"環境値を読む"| cfg
    scripts -->|"ログ+JSONを書く"| ev
    hil -->|"OpenOCD/UART"| extHw
    scripts -->|"明示ELFで任意Wokwi"| extWokwi
    ciw --> extCI
    extCI -->|"証拠/ファーム"| art
    scripts -->|"取得"| art
    docs -.->|"規程/手順を参照"| scripts
```

## 読み方

- **`scripts/` が標準操作入口**です。AIも人間もここを通し、任意シェル実行はしません(設計方針: [../design/MCP_SETUP.md](../design/MCP_SETUP.md))。証拠付き入口(`build.sh`, `verify_all.sh`, 実機/観測wrapper)がログ+JSONを生成し、低レベル部品(`build_firmware.sh`, `test_ctest.sh`, `test_wokwi.sh`)は呼び出し元が証拠化します。
- **証拠は2系統**: 実行のたびに生まれる `evidence/latest/`(使い捨て)と、教材用に残す `evidence/samples/`(Git管理、来歴つき)。
- **設定の外出し**: ローカル依存値(UARTポート等)は `config/hardware.local.yaml` か環境変数。コードには直書きしません。
- **ビルド出力の分離**: ホスト直ビルドは `build/`、Docker経由は `build-docker/`(`PICO_BUILD_DIR` で切替)。Wokwi/実機系は共通ヘルパーで対象ELFを解決し、衝突回避のため別ディレクトリを維持します。詳細は [06_deployment.md](06_deployment.md)。

## Source of Truth

- 構成の一覧: [../../SYSTEM_DESIGN.md](../../SYSTEM_DESIGN.md)
- 証拠ポリシー: [../operations/TEST_EVIDENCE_POLICY.md](../operations/TEST_EVIDENCE_POLICY.md)
- `scripts/` の内部は [03_components_scripts.md](03_components_scripts.md) へ
