# 環境テスト仕様書 (Environment Test Specification)

## 1. テスト方針
開発環境そのものが正常に構築され、機能していることを検証するためのテスト手順を定義する。

## 2. 環境構築テスト (Build Verification Test)
### 2.1 コンテナビルドテスト
*   **テストID**: ENV-001
*   **目的**: `Dockerfile` からDockerイメージが正常にビルドできることを確認する。
*   **手順**:
    1.  `docker build -f .devcontainer/Dockerfile .` を実行する。
*   **合格基準**: エラーなく終了し、イメージIDが出力されること。

### 2.2 ツールチェーン存在確認
*   **テストID**: ENV-002
*   **目的**: 必要なツールがパスの通った場所にインストールされていることを確認する。
*   **手順**: コンテナ内で以下のコマンドを実行する。
    1.  `arm-none-eabi-gcc --version`
    2.  `cmake --version`
    3.  `make --version`
*   **合格基準**:
    *   GCC: 11.3.rel1 であること。
    *   CMake: 3.x 以上であること。
    *   各コマンドがエラーなくバージョン情報を返すこと。

### 2.3 SDKパス確認
*   **テストID**: ENV-003
*   **目的**: `PICO_SDK_PATH` 環境変数が正しく設定されていることを確認する。
*   **手順**: `echo $PICO_SDK_PATH` を実行する。
*   **合格基準**: `/apps/pico-sdk` (または設定したパス) が出力され、そのディレクトリが存在すること。

## 3. パイプライン連携テスト (Pipeline Integration Test)
### 3.1 ローカル統合スクリプトテスト
*   **テストID**: ENV-004
*   **目的**: `build_and_test.sh` が環境差異を吸収して動作することを確認する。
*   **手順**: コンテナ内で `./build_and_test.sh` を実行する。
*   **合格基準**: Configure, Build, Test の全フェーズが成功すること。

### 3.2 CIワークフローテスト
*   **テストID**: ENV-005
*   **目的**: GitHub Actions 上で環境が再現され、ビルドが通ることを確認する。
*   **手順**:
    1.  コードをGitHubにプッシュする。
    2.  "Actions" タブで "Build and test" ワークフローの状態を確認する。
*   **合格基準**:
    *   ワークフローが緑色（Success）で終了すること。
    *   "Upload firmware artifacts" ステップでアーティファクトがアップロードされていること。

## 4. シミュレータ連携テスト
### 4.1 Wokwi 自動テスト (Automated Wokwi Test)
*   **テストID**: ENV-006
*   **目的**: Wokwi CLI を用いてファームウェアの機能テストが自動実行できることを確認する。
*   **手順**:
    1.  (CI) GitHub Actions の "Test on Wokwi" ジョブが成功することを確認する。
    2.  (Local) `WOKWI_CLI_TOKEN` を設定し、`./build_and_test.sh` を実行する。
*   **合格基準**:
    1.  CIジョブが緑色（Success）になること。
    2.  ローカル実行時、"Running Wokwi test..." と表示され、テストが Pass すること。
