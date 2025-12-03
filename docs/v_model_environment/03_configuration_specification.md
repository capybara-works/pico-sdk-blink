# 環境構成仕様書 (Environment Configuration Specification)

## 1. コンテナ定義詳細
`.devcontainer/Dockerfile` に基づく詳細構成仕様。

### 1.1 ベースイメージ
*   **Image**: `mcr.microsoft.com/vscode/devcontainers/cpp`
*   **Tag**: `0-ubuntu-22.04`
*   **Variant**: Ubuntu 22.04 LTS (Jammy Jellyfish)

### 1.2 インストールパッケージ (APT)
以下のパッケージを `apt-get` でインストールする。
*   `cmake`
*   `build-essential`
*   `wget`, `ca-certificates`
*   `gdb-multiarch`
*   `automake`, `autoconf`, `libtool`
*   `libftdi-dev`, `libusb-1.0-0-dev`
*   `pkg-config`
*   `clang-format`
*   `libhidapi-dev`

### 1.3 ARM ツールチェーン
*   **提供元**: ARM Developer (GNU Toolchain)
*   **バージョン**: 11.3.rel1
*   **ファイル名**: `arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-eabi.tar.xz`
*   **インストール先**: `/apps/gcc-arm-none`
*   **PATH設定**: `/apps/gcc-arm-none/bin` をPATHに追加。

### 1.4 Raspberry Pi Pico SDK
*   **リポジトリ**: `https://github.com/raspberrypi/pico-sdk.git`
*   **ブランチ**: `master` (または特定のタグ)
*   **インストール先**: `/apps/pico-sdk`
*   **環境変数**: `PICO_SDK_PATH=/apps/pico-sdk`

### 1.5 追加ツール
*   **OpenOCD**:
    *   リポジトリ: `https://github.com/openocd-org/openocd.git`
    *   構成オプション: `--enable-ftdi --enable-sysfsgpio --enable-picoprobe --enable-cmsis-dap`
*   **Picotool**:
    *   リポジトリ: `https://github.com/raspberrypi/picotool.git`
    *   インストール先: `/usr/local/bin/picotool`

## 2. VS Code 拡張機能構成
`.devcontainer/devcontainer.json` および `.vscode/extensions.json` に基づく。

### 2.1 必須拡張機能
| ID | 名称 | 用途 |
| :--- | :--- | :--- |
| `ms-vscode.cpptools` | C/C++ | インテリセンス、デバッグ |
| `ms-vscode.cmake-tools` | CMake Tools | CMake統合、ビルド支援 |
| `marus25.cortex-debug` | Cortex-Debug | ARMマイコンデバッグ支援 |
| `Wokwi.wokwi-vscode` | Wokwi Simulator | 回路シミュレーション |
| `xaver.clang-format` | Clang-Format | コードフォーマッター |

## 3. プロジェクト設定
### 3.1 CMake設定 (`CMakeLists.txt`)
*   **最小バージョン**: 3.13
*   **C標準**: C11
*   **C++標準**: C++17
*   **SDKインポート**: `pico_sdk_import.cmake` を使用して `PICO_SDK_PATH` を解決。
