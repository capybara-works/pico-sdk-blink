# 環境構築ガイド (Environment Setup Guide)

本文書では、本プロジェクトと同等の開発環境を構築する手順について説明します。本プロジェクトでは、DevContainersと統一されたビルドスクリプトを使用することで、**再現性 (Reproducibility)** を重視しています。

## 1. 推奨手順: DevContainer (Docker)

環境を再現する最も確実な方法は、VS Code DevContainersを使用することです。これにより、元の環境と全く同じツールチェーンバージョン (GCC 11.3.rel1, CMake等) が保証されます。

### 前提条件
- **VS Code** がインストールされていること。
- **Docker Desktop** (または同等のDockerエンジン) がインストールされ、実行されていること。
- VS Code拡張機能 **Dev Containers** がインストールされていること。

### 手順
1.  リポジトリをクローンします。
2.  VS Codeでフォルダを開きます。
3.  "Reopen in Container" (コンテナで再度開く) というプロンプトが表示されたら、**Reopen** をクリックします。
    -   または、`F1` キーを押して **Dev Containers: Reopen in Container** を選択します。
4.  コンテナのビルドが完了するのを待ちます (依存関係がすべて自動的にインストールされます)。

**自動的にインストールされるもの:**
-   ARM GCC Toolchain (11.3.rel1)
-   CMake, Build Essentials
-   Pico SDK
-   OpenOCD (ハードウェアデバッグ用)
-   Picotool
-   VS Code Extensions (C/C++, Wokwi, Cortex-Debug, etc.)

### 1.5 Docker CLIによるビルド (VS Code不要)

VS Codeを使用せず、Dockerのみでビルドとテストを実行したい場合は、以下のスクリプトを使用できます。

```bash
# スクリプトに実行権限を付与
chmod +x docker_build.sh

# Dockerコンテナ内でビルドとテストを実行
./docker_build.sh
```

このスクリプトは以下の処理を自動化します:
1.  `.devcontainer/Dockerfile` を使用してDockerイメージをビルドします。
2.  コンテナを起動し、カレントディレクトリをマウントします。
3.  コンテナ内で `build_and_test.sh` を実行します。

---

## 2. 手動セットアップ (ローカル環境)

Dockerを使用できない場合は、以下の手順に従ってOS (macOS/Linux/Windows) に直接環境を構築してください。

### 2.1 共通の前提条件
-   **VS Code**: 推奨エディタ。
-   **Python 3.x**: テストスクリプトに必要。
-   **Git**: バージョン管理用。

### 2.2 ツールチェーンのインストール

#### macOS
```bash
# CMakeとその他のツールをインストール
brew install cmake ninja

# ARM GCC Toolchain (厳密な互換性のために11.3を推奨)
# Homebrewも使用可能ですが、バージョンが異なる場合があります。
brew install --cask gcc-arm-embedded
# バージョン確認: arm-none-eabi-gcc --version
```

#### Linux (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install cmake build-essential wget git python3

# ARM GCC 11.3.rel1 のインストール (一貫性のため手動インストールを推奨)
wget https://developer.arm.com/-/media/Files/downloads/gnu/11.3.rel1/binrel/arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-eabi.tar.xz
tar xf arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-eabi.tar.xz
sudo mv arm-gnu-toolchain-11.3.rel1-x86_64-arm-none-eabi /usr/local/arm-none-eabi
echo 'export PATH=$PATH:/usr/local/arm-none-eabi/bin' >> ~/.bashrc
source ~/.bashrc
```

#### Windows
1.  **CMake** をインストールします。
2.  **ARM GNU Toolchain** をインストールします (ARMのWebサイトからインストーラを入手可能)。
3.  **MinGW** または **Visual Studio Build Tools** をインストールします (Make/Ninja用)。
4.  すべてのbinフォルダを `PATH` に追加します。

### 2.3 Pico SDK セットアップ
1.  SDKをクローンします:
    ```bash
    mkdir -p ~/pico
    cd ~/pico
    git clone https://github.com/raspberrypi/pico-sdk.git --branch 2.0.0
    cd pico-sdk
    git submodule update --init
    ```
2.  環境変数を設定します:
    ```bash
    export PICO_SDK_PATH=~/pico/pico-sdk
    ```

### 2.4 Wokwi セットアップ (推奨オプション)
自動シミュレーションを実行する場合:
1.  [Wokwi CI Dashboard](https://wokwi.com/dashboard/ci) からトークンを取得します。
2.  環境変数を設定します:
    ```bash
    export WOKWI_CLI_TOKEN="your_token_here"
    ```

---

## 3. 動作確認

環境が正しくセットアップされているか確認するために、統合ビルド・テストスクリプトを実行します。

```bash
# スクリプトに実行権限を付与
chmod +x build_and_test.sh

# ビルドとテストを実行
./build_and_test.sh
```

**成功基準:**
-   CMakeのConfigureがエラーなく完了する。
-   ビルドが完了し、`build/blink.elf` が生成される。
-   テスト (サイズチェック等) がパスする。

---

## 4. 実機テスト環境 (HIL) - オプション

実機 (Raspberry Pi Pico) を使用した Hardware-in-the-Loop テストを行う場合:

1.  **ハードウェア**: Raspberry Pi Debug Probe + Raspberry Pi Pico.
2.  **ソフトウェア**: OpenOCD (v0.12.0以上).
3.  **配線**: `docs/HIL_RESEARCH_REPORT.md` の記述に従い、SWDとUARTを接続します。
4.  **テスト実行**:
    ```bash
    python3 hil_runner.py --test blink.test.yaml --elf build/blink.elf
    ```
