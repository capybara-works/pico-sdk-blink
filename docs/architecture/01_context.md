# 01. システムコンテキスト (C4: System Context)

このラボを**一番外側のズーム**で見た図です。「誰が使い、どの外部システムと関わるか」だけを示し、
内部構造には踏み込みません。まずここで全体の輪郭を掴みます。

```mermaid
flowchart LR
    human["人間 / AIエージェント"]
    subgraph lab["Embedded AI Agent Lab (本リポジトリ)"]
        core["検証ループ<br/>scripts + evidence + docs"]
    end
    wokwi["Wokwi<br/>シミュレータ"]
    hw["Raspberry Pi Pico<br/>+ Debug Probe (実機)"]
    la["ロジックアナライザ<br/>FX2LP/sigrok"]
    ci["GitHub Actions<br/>CI"]
    ghcr["GHCR<br/>devcontainerイメージ"]

    human -->|"意図・コード変更"| lab
    lab -->|"verification.md / 一次証拠"| human
    lab -->|"ビルド成果物でシミュレーション"| wokwi
    wokwi -->|"UARTログ判定"| lab
    lab -->|"flash / UART / GDB"| hw
    hw -->|"観測値"| lab
    lab -.->|"UART/I2C等のデコード<br/>(PICO_LOGIC_* gate)"| la
    lab -->|"push"| ci
    ci -->|"証拠 / ファームウェア artifact"| lab
    ghcr -->|"事前ビルド済み環境"| lab
    ci -->|"イメージ公開"| ghcr
```

## 読み方

- **中心(ラボ)** は、AIや人間が出した「コード変更」を受け取り、**証拠(verification.md と一次ログ/JSON)**を返す存在です。
- 外部システムは大きく3系統:**シミュレーション**(Wokwi)、**実機観測**(Pico+Debug Probe、ロジックアナライザ)、**CI/配布**(GitHub Actions と GHCR)。
- 実機とロジックアナライザへの経路は、安全ゲート(`PICO_HARDWARE` / `PICO_LOGIC_UART` / `PICO_LOGIC_I2C` / `PICO_LOGIC_ANALYZER`)が無い限り起動しません。詳細は [04_verification_flow.md](04_verification_flow.md)。

## Source of Truth

- 全体方針: [../../README.md](../../README.md), [../../SYSTEM_DESIGN.md](../../SYSTEM_DESIGN.md)
- CI/イメージ: [../../.github/workflows/ci.yml](../../.github/workflows/ci.yml), [../../.github/workflows/devcontainer-image.yml](../../.github/workflows/devcontainer-image.yml)
