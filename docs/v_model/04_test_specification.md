# テスト仕様書 (Test Specification Document)

## 1. テスト方針
本プロジェクトでは、ローカル環境およびCI環境（GitHub Actions）において、自動化されたテストを実施する。

## 2. 単体テスト (Unit Test)
### 2.1 ビルド検証
*   **テストID**: UT-001
*   **目的**: ソースコードが正常にコンパイル・リンクできることを確認する。
*   **手順**: `cmake --build .` を実行する。
*   **合格基準**: エラーなく終了し、実行用ファームウェア（`blink.elf`, `blink.uf2`, `blink.bin`）が生成されること。

### 2.2 サイズチェック
*   **テストID**: UT-002
*   **目的**: 生成されたバイナリが有効であることを簡易的に確認する。
*   **手順**: CTestの `size_check` テストを実行する（`arm-none-eabi-size` コマンドを使用）。
*   **合格基準**: コマンドが正常終了すること。

## 3. 結合テスト (Integration Test)
Wokwiシミュレータを使用したハードウェア・ソフトウェア連携テストを実施する。

### 3.1 シナリオテスト: Lチカとログ出力
*   **テストID**: IT-001
*   **目的**: LED制御ロジックが実行され、状態変化に対応するシリアルログが出力されることを確認する。
*   **定義ファイル**: `blink.test.yaml`
*   **手順**:
    1.  シミュレーションを開始する。
    2.  シリアル出力 "LED on" を待機する。
    3.  (内部LEDのため、ピン状態の直接検証はスキップし、ロジック到達をシリアルログで確認する)
    4.  シリアル出力 "LED off" を待機する。
*   **合格基準**: 上記ステップがタイムアウト（5000ms）内に全て成功すること。

### 3.2 シナリオテスト: Wokwi I2C題材
*   **テストID**: IT-002
*   **目的**: Wokwi上の仮想SSD1306 OLEDがI2Cデバイスとして検出され、LED制御ログも継続して出力されることを確認する。
*   **定義ファイル**: `blink_i2c.test.yaml`
*   **手順**:
    1.  シミュレーションを開始する。
    2.  シリアル出力 "I2C scan start" を待機する。
    3.  シリアル出力 "I2C device: 0x3C" を待機する。
    4.  シリアル出力 "I2C scan done" を待機する。
    5.  シリアル出力 "POST " を待機する（起動時自己診断行の出力確認）。
    6.  シリアル出力 "LED on" / "LED off" を待機する。
*   **合格基準**: 上記ステップがタイムアウト（10000ms）内に全て成功すること。
*   **補足**: POST行は `POST fw=... vsys_raw=... vsys_mv=... temp_mc=... vbus=... i2c_oled=...` 形式。
    Wokwiは電源/ADCを模擬しないため `vsys_*`/`temp_mc`/`vbus` は非物理値になり、
    シナリオは行の存在のみを判定する。これらの値が意味を持つのは実機(HIL)。
    実機検証済み(2026-06-16): `vsys_mv=4975`(≒4.98V, USB給電VSYS正常)。
    vsysは高インピーダンス分圧のため整定+多数平均が必須(`adc_avg()`)。

## 4. CI/CD検証 (System Verification)
GitHub Actions (`.github/workflows/ci.yml`) 上で以下のプロセスが正常に完了することを以て、システム全体の健全性を保証する。

### 4.1 ビルド検証ジョブ (build-and-test)
1.  **Checkout**: リポジトリの取得。
2.  **Toolchain Setup**: ARM GCC, CMake のインストール。
3.  **SDK Setup**: Pico SDK (v2.0.0) の取得とキャッシュ。
4.  **Build & Test**: `scripts/build.sh` の実行（Configure, Build, CTest, 任意Wokwi）。
5.  **Artifact Upload**: 生成されたファームウェア (`build/blink.*`: `blink.uf2`, `blink.bin`, `blink.elf`, map/disassembly 等) の保存。

### 4.2 Wokwi統合テストジョブ (test-on-wokwi)
*   **テストID**: SV-001
*   **依存関係**: `build-and-test` ジョブの正常完了
*   **目的**: シミュレータ環境でのハードウェア・ソフトウェア統合動作を検証する。
*   **実行環境**: `wokwi/wokwi-ci-action@v1`
*   **手順**:
    1.  ビルド済みファームウェア artifact (`build/blink.*`) を `build/` にダウンロード。
    2.  Wokwi CIアクションでシミュレーションを起動。
    3.  `blink_i2c.test.yaml` で定義されたWokwi専用テストシナリオ (IT-002) を実行。
    4.  シリアル出力の検証結果を取得し、`evidence-with-wokwi` artifact に `wokwi_result.json` と `verification.md` を保存。
*   **必須設定**: GitHubリポジトリシークレット `WOKWI_CLI_TOKEN` の設定
*   **タイムアウト**: 10000ms
*   **合格基準**: テストシナリオの全ステップがタイムアウト内に成功すること。
