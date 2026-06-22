# 環境テスト仕様書 (Environment Test Specification)

## 1. テスト方針
開発環境そのものが正常に構築され、機能していることを検証するためのテスト手順を定義する。

## 2. 環境構築テスト (Build Verification Test)
### 2.1 コンテナビルドテスト
*   **テストID**: ENV-001
*   **目的**: 事前ビルド済みDevContainerイメージまたは `Dockerfile` からDocker実行環境を準備でき、コンテナ内でローカル検証入口が実行できることを確認する。
*   **手順**:
    1.  `./docker_build.sh` を実行する。
    2.  ローカルDockerfileビルドも確認する場合は、`PICO_DOCKER_FORCE_BUILD=1 ./docker_build.sh` を実行する。
    3.  イメージ単体だけを確認する場合は、`docker build --platform linux/amd64 -t pico-sdk-blink-dev -f .devcontainer/Dockerfile .devcontainer` を実行する。
*   **合格基準**:
    *   `./docker_build.sh` が `linux/amd64` の事前ビルド済みイメージをpullできる場合はそれを使用し、取得できない場合は同platformのローカルビルドへfallbackすること。
    *   ローカルDockerfileビルドがエラーなく完了すること。
    *   `./docker_build.sh` 実行時、コンテナ内で `PICO_BUILD_DIR=/workspace/build-docker scripts/build.sh` が実行されること。
    *   `build-docker/` に `blink.elf`, `blink.uf2`, `blink.bin` が生成されること。
    *   Build と CTest が `pass` になり、Wokwiはtoken未設定時に `skip`、設定時に `pass` として証拠に記録されること。
    *   Wokwi実行時は `build-docker/blink.elf` と `blink_i2c.test.yaml` がCLIへ明示され、`wokwi_result.json` に対象artifactのパスとhashが記録されること。

### 2.2 ツールチェーン存在確認
*   **テストID**: ENV-002
*   **目的**: 必要なツールがパスの通った場所にインストールされていることを確認する。
*   **手順**: コンテナ内で以下のコマンドを実行する。
    1.  `arm-none-eabi-gcc --version`
    2.  `cmake --version`
    3.  `make --version`
    4.  `wokwi-cli --version`
    5.  `python3 -c "import serial, yaml"`
*   **合格基準**:
    *   GCC: 11.3.rel1 であること。
    *   CMake: 3.x 以上であること。
    *   Wokwi CLI: v0.26.1 であること。
    *   `python3 -c "import serial, yaml"` が成功すること。
    *   各コマンドがエラーなくバージョン情報を返すこと。

### 2.3 SDKパス確認
*   **テストID**: ENV-003
*   **目的**: `PICO_SDK_PATH` 環境変数が正しく設定されていることを確認する。
*   **手順**: `echo $PICO_SDK_PATH` を実行する。
*   **合格基準**: `/apps/pico-sdk` (または設定したパス) が出力され、そのディレクトリが存在すること。

## 3. パイプライン連携テスト (Pipeline Integration Test)
### 3.1 ローカル統合スクリプトテスト
*   **テストID**: ENV-004
*   **目的**: `scripts/build.sh` が環境差異を吸収して動作し、Build / CTest / Wokwi の個別証拠を生成することを確認する。
*   **手順**: コンテナ内で `scripts/build.sh` を実行する。
*   **合格基準**: Configure, Build, CTest が成功し、Wokwiはtoken設定時に成功、未設定時は `skip` として記録されること。

### 3.2 CIワークフローテスト
*   **テストID**: ENV-005
*   **目的**: GitHub Actions 上で環境が再現され、ビルドが通ることを確認する。
*   **手順**:
    1.  コードをGitHubにプッシュする。
    2.  "Actions" タブで "Build and test" ワークフローの状態を確認する。
*   **合格基準**:
    *   ワークフローが緑色（Success）で終了すること。
    *   "Upload firmware artifacts" ステップでアーティファクトがアップロードされていること。
    *   `evidence` および `evidence-with-wokwi` アーティファクトがアップロードされていること。
    *   `scripts/fetch_ci_evidence.sh` で `evidence-with-wokwi` を取得できること。

### 3.3 Docker/CI ファームウェアpayload一致確認
*   **テストID**: ENV-006
*   **目的**: DevContainer相当環境で生成した実行用payloadとCI artifactが一致することを確認する。
*   **手順**:
    1.  `./docker_build.sh` を実行し、`build-docker/` の成果物を生成する。
    2.  `scripts/fetch_ci_firmware.sh <run_id>` を実行し、対象CI runの `firmware` artifactを `artifacts/latest/firmware/<run_id>/` に取得する。
    3.  `shasum -a 256 build-docker/blink.uf2 artifacts/latest/firmware/<run_id>/blink.uf2` を実行する。
    4.  `shasum -a 256 build-docker/blink.bin artifacts/latest/firmware/<run_id>/blink.bin` を実行する。
*   **合格基準**:
    *   `blink.uf2` のhashが一致すること。
    *   `blink.bin` のhashが一致すること。
    *   Pico SDKのbinary info build date固定により、日付境界だけでpayload hashが変化しないこと。
    *   `blink.elf`, `.map`, `.dis` はビルドパスやデバッグ情報を含むため、payload一致の必須判定対象にしない。

### 3.4 DevContainerイメージ公開テスト
*   **テストID**: ENV-007
*   **目的**: `.devcontainer/Dockerfile` から事前ビルド済みDevContainerイメージが生成され、GHCRに公開されることを確認する。
*   **手順**:
    1.  `.github/workflows/devcontainer-image.yml` を手動実行、または `.devcontainer/**` の変更を `main` に反映する。
    2.  "Build devcontainer image" ワークフローの状態を確認する。
    3.  `docker pull ghcr.io/capybara-works/pico-sdk-blink/devcontainer:main` を実行する。
*   **合格基準**:
    *   ワークフローが緑色（Success）で終了すること。
    *   `ghcr.io/capybara-works/pico-sdk-blink/devcontainer:main` と `sha-<commit>` タグが公開されること。
    *   pullしたイメージを `docker_build.sh` がローカル名 `pico-sdk-blink-dev` として使用できること。

## 4. シミュレータ連携テスト
### 4.1 Wokwi 自動テスト (Automated Wokwi Test)
*   **テストID**: ENV-008
*   **目的**: Wokwi CLI を用いて、仮想SSD1306 OLEDのI2C検出、初期化、ページ送信、UARTログ出力の機能テストが自動実行できることを確認する。
*   **手順**:
    1.  (CI) GitHub Actions の "Test on Wokwi" ジョブが成功することを確認する。
    2.  (Local) `WOKWI_CLI_TOKEN` を設定し、`scripts/build.sh` を実行する。
*   **合格基準**:
    1.  CIジョブが緑色（Success）になること。
    2.  CIの `evidence-with-wokwi` に `wokwi_result.json` が保存され、`status` が `pass` であること。
    3.  ローカル実行時、"Running Wokwi test..." と表示され、`blink_i2c.test.yaml` が Pass すること。
    4.  `wokwi_result.json` の `artifacts["blink.elf"].path` が、その実行で指定した `PICO_BUILD_DIR` 配下を指すこと。
