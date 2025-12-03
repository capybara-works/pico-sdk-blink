# Development Guide & Contributing

本プロジェクトは **"Embedded Vibe Coding"** スタイルで開発されています。
AIアシスタントと協調し、効率的に開発を進めるためのガイドラインです。

## 1. Vibe Coding Workflow

「自分でコードを書く」のではなく、「AIに意図を伝えて実装させる」ことを基本とします。

### Step 1: Define the "Vibe" (意図の伝達)
やりたいことを自然言語で明確に伝えます。
*   **Bad**: 「LEDのコードを直して」
*   **Good**: 「ボタンを追加して、押している間だけLEDが2倍の速さで点滅するようにしたい。GP15を使って。」

### Step 2: AI-Driven Implementation (AIによる実装)
AIは以下の順序で変更を行います。
1.  **Hardware**: `diagram.json` を修正し、配線を変更。
2.  **Software**: `blink.cpp` 等のソースコードを修正。
3.  **Build & Test**: `build_and_test.sh` を実行し、動作を検証。

### Step 3: Verification (検証)
*   **Wokwi**: VS Code上でシミュレータを起動し、視覚的に動作確認。
*   **CI**: GitHub Actionsがパスすることを確認。

---

## 2. Testing Strategy

本プロジェクトでは、**Wokwi Automation** を用いた自動テストを採用しています。

### テストの仕組み
*   **シナリオ定義**: `blink.test.yaml`
*   **実行エンジン**: `wokwi-cli` (ローカル) / `wokwi-ci-action` (CI)

### 新しいテストの追加方法
機能を追加した際は、必ずテストもセットでAIに生成させてください。

1.  **シナリオファイルの更新**:
    `blink.test.yaml` に新しいテストケースを追記します。
    ```yaml
    - name: "Button Press Test"
      steps:
        - press: "button1"  # ボタンを押す
        - wait: 100         # 100ms待つ
        - expect-pin: 25:1   # GP25(内部LED)がHighであることを期待 (実機のみ)
    ```

2.  **ローカル実行**:
    ```bash
    ./build_and_test.sh
    ```
    ※ 現在の `build_and_test.sh` は基本的なビルドチェック（`size_check`）のみを行います。
    
    Wokwiのシナリオテストを実行するには、別途以下のコマンドを実行してください：
    ```bash
    wokwi-cli . --scenario blink.test.yaml --timeout 1000
    ```

## 3. Troubleshooting

エラーが発生した場合のゴールデンルール：
**「エラーログを読み解こうとせず、そのままAIに貼り付ける」**

AIはビルドログやコンパイラのエラーメッセージから、文法ミスやリンクエラーを即座に特定し、修正案を提示します。
