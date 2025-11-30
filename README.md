# Pico SDK Blink Project

![Build and test](https://github.com/capybara-works/pico-sdk-blink/actions/workflows/ci.yml/badge.svg)

Raspberry Pi Pico (RP2040) 用のLED点滅サンプルプロジェクトです。
Wokwiシミュレータでの動作確認、およびGitHub ActionsによるCI/CDパイプラインに対応しています。

## 💡 コンセプト (Concept)

**"Embedded Vibe Coding with AI-driven CI/CD"**

本プロジェクトは、単なるLチカのサンプルではなく、**AIと協調して高速に組み込み開発を行うための実験的環境**です。

*   **Vibe Coding**: 人間は「意図（Vibe）」と「設計」に集中し、実装の細部はAIに任せるスタイル。
*   **AI-Driven**: 環境構築、ビルドスクリプト作成、ドキュメント生成をAIが主導。
*   **Robust Foundation**: ローカルとCIで統一されたビルド・テスト環境 (`build_and_test.sh`) が、AI生成コードの動作を即座に保証します。

## 📋 前提条件 (Prerequisites)

このプロジェクトをローカルでビルド・開発するには、以下のツールが必要です。

*   **Pico SDK**: Raspberry Pi Pico SDK (v1.5.0以上推奨, CIはv2.0.0使用)
*   **CMake**: ビルドシステム
*   **GCC ARM Toolchain**: クロスコンパイラ (`arm-none-eabi-gcc`)
*   **VS Code**: 推奨エディタ (Wokwi拡張機能利用のため)

## ☁️ クラウド開発 (GitHub Codespaces)

本プロジェクトは **GitHub Codespaces** に対応しています。
ブラウザ上でVS Code環境を即座に立ち上げ、環境構築なしで開発を開始できます。

1.  GitHubリポジトリの **[<> Code]** ボタンをクリック。
2.  **[Codespaces]** タブを選択し、**[Create codespace on main]** をクリック。
3.  自動的にPico SDK等のツールチェーンがセットアップされます。

## 🛠️ ローカル開発 (Local Development)

### ビルドとテスト (推奨)

ローカル環境とCI環境の差異をなくすため、統合スクリプト `build_and_test.sh` の使用を推奨します。
このスクリプトは、CMakeのConfigure、Build、およびCTestによるテスト実行を一括で行います。

```bash
# 実行権限の付与（初回のみ）
chmod +x build_and_test.sh

# ビルドとテストの実行
./build_and_test.sh
```

### 手動ビルド

従来のCMakeコマンドによるビルドも可能です。

```bash
mkdir -p build
cd build
cmake ..
make -j4
```

## 🚀 CI/CD パイプライン

GitHub Actions (`.github/workflows/ci.yml`) により、以下のプロセスが自動化されています。

1.  **環境構築**: 必要なツールチェーンとPico SDK (v2.0.0) のセットアップ。
2.  **ビルド & テスト**: ローカルと同じ `build_and_test.sh` を使用して実行。
3.  **アーティファクト保存**: ビルド成果物 (`blink.uf2`, `blink.elf`) を保存。

## 💻 Wokwi シミュレーション

[Wokwi for VS Code](https://marketplace.visualstudio.com/items?itemName=wokwi.wokwi-vscode) を使用して、実機なしで動作確認が可能です。

1.  VS Codeでプロジェクトを開く。
2.  `diagram.json` を開くか、コマンドパレット (F1) から **"Wokwi: Start Simulator"** を選択。
3.  LEDが点滅することを確認。

## 🤖 AIアシスタント活用ガイド

このプロジェクトの開発において、AIアシスタント（Antigravity等）は以下の場面で活用できます。

### 1. 環境構築トラブルシューティング
ビルドエラーが発生した場合、エラーログをそのまま共有することで、原因（パス設定漏れ、ツールチェーン不整合など）の特定と解決策の提示が可能です。

### 2. Wokwi構成の変更
新しいセンサーやパーツを追加したい場合、「Wokwiでボタンを追加してGP15に接続したい」と指示することで、`diagram.json` の定義と配線情報を生成できます。

### 3. CMake設定の管理
ライブラリの追加やビルドオプションの変更が必要な場合、`CMakeLists.txt` の適切な修正箇所を提案できます。

---
*Documented by Antigravity*
