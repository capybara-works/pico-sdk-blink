# 環境アーキテクチャ設計書 (Environment Architecture Design)

## 1. 全体アーキテクチャ
本環境は、Dockerコンテナを基盤とし、その上で開発ツール、SDK、シミュレータが連携する多層構造となっている。

### 1.1 レイヤー構造図
```mermaid
graph TD
    subgraph "Host OS (Mac/Win/Linux)"
        Docker[Docker Runtime]
        VSCode[VS Code Client]
    end

    subgraph "Dev Container (Ubuntu 22.04)"
        OS[OS Layer: Ubuntu 22.04 LTS]
        Toolchain[Toolchain Layer: ARM GCC 11.3, CMake, Make]
        SDK[SDK Layer: Pico SDK, Picotool, OpenOCD]
        App[Application Layer: Source Code, Build Scripts]
    end

    subgraph "Verification"
        Wokwi[Wokwi Simulator (CLI/VSCode Ext)]
        TestScript[Test Scripts (ctest, bash)]
    end

    VSCode -->|Remote Connection| App
    App -->|Build| Toolchain
    Toolchain -->|Link| SDK
    App -->|Test| Wokwi
    Wokwi -->|Result| TestScript
```

## 2. コンポーネント設計
### 2.1 コンテナ基盤
*   **Base Image**: `mcr.microsoft.com/vscode/devcontainers/cpp:0-ubuntu-22.04`
*   **役割**: 開発に必要なOSライブラリと基本ツール（git, curl等）を提供する。

### 2.2 ツールチェーン
*   **ARM GCC**: `arm-none-eabi-gcc` バージョン 11.3.rel1
    *   役割: クロスコンパイル。
*   **CMake**: ビルド設定と依存関係解決。
*   **Build Essentials**: `make` 等のビルド実行ツール。

### 2.3 SDK & ライブラリ
*   **Pico SDK**: Raspberry Pi Pico 用の公式SDK。
    *   配置: `/apps/pico-sdk` (コンテナ内)
    *   管理: Git submodule または `pico_sdk_import.cmake` による自動取得。
*   **OpenOCD**: デバッグ用プロキシ（実機デバッグ用）。
*   **Picotool**: バイナリ情報の検査ツール。

### 2.4 CI/CD連携
*   **GitHub Actions**: CIランナー。
*   **Workflow**: `.github/workflows/ci.yml`
    *   役割: コンテナ環境の再現（または同等のツールチェーンセットアップ）と、`scripts/ci_phase1_smoke.sh` / `scripts/verify_all.sh` の実行。

## 3. データフロー
1.  **Code Change**: ユーザーまたはAIがソースコードを変更。
2.  **Sync**: VS Code Server がコンテナ内のファイルを更新。
3.  **Build Trigger**: ユーザーがコマンド実行、またはタスク実行。
4.  **Compile**: `cmake` -> `make` が走り、`PICO_BUILD_DIR` 配下に `blink.elf` を生成する(既定は `build/`、Docker経由は `build-docker/`)。
5.  **Test Trigger**: `scripts/build.sh` または個別の `scripts/test_ctest.sh` / `scripts/test_wokwi.sh` が実行。
6.  **Simulation**: Wokwi CLI が `diagram.json` と既定シナリオ `blink_i2c.test.yaml` を使い、`PICO_BUILD_DIR` 配下の `blink.elf` を `--elf` で明示してI2Cスキャン + UARTログシナリオを検証する。実機HILは `blink.test.yaml` を使う。VS Code等の手動起動では `wokwi.toml` の既定パスも使用する。
7.  **Feedback**: テスト結果（Pass/Fail）がコンソールおよびCIバッジとして返却される。
