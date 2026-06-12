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
3.  **Build & Test**: `scripts/build.sh` (または `scripts/verify_all.sh`) を実行し、動作を検証。

### Step 3: Verification (検証)

標準の検証手順:

1.  変更目的と影響範囲を確認する
2.  変更後に `scripts/build.sh` を実行する
3.  必要に応じて `scripts/verify_all.sh` を実行する(実機なしでも安全)
4.  実機検証が必要な場合のみ `PICO_HARDWARE=1` を付ける
5.  ロジックアナライザ実測が必要な場合のみ `PICO_LOGIC_ANALYZER=1` を付ける
6.  `evidence/latest/verification.md` を確認する
7.  必要に応じて一次証拠 (`build.log`, `*_result.json` 等) も確認する
8.  pass / fail / partial / skipped を**証拠に基づいて**判断する
9.  **skip / stub を成功扱いしない**
10. 変更内容・検証結果・残課題をコミットまたはPRに明記する

あわせて Wokwi (シミュレーション/UARTログ確認) と GitHub Actions (CI) も活用してください。
判定基準の詳細: `docs/operations/AGENT_OPERATION.md`, `docs/operations/TEST_EVIDENCE_POLICY.md`

### AIエージェント向け注意

*   証拠なしに「成功」と書かない
*   生成スクリーンショットを証拠扱いしない
*   任意シェル実行を前提にしない(`scripts/` の固定入口を使う)
*   実機操作は `PICO_HARDWARE=1` で明示的に有効化された場合のみ行う
*   `verification.md` は要約であり、必要に応じて一次証拠ログも確認する

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
    name: Button press smoke
    version: 1
    steps:
      - wait-serial: "LED on"
    ```
    現在のHIL runnerがサポートする共通stepは `wait-serial` です。
    `expect-pin` や `press` / `wait` などの未対応stepはHILでは明示的に失敗します。

2.  **ローカル実行**:
    ```bash
    scripts/build.sh
    ```
    `WOKWI_CLI_TOKEN` が設定されている場合、`scripts/build.sh` はWokwiシナリオも実行します。
    未設定の場合、Wokwiステップはskipされ、ビルドと `size_check` のみ実行されます。

    Wokwiのシナリオテストだけを直接実行する場合:
    ```bash
    wokwi-cli . --scenario blink.test.yaml --timeout 5000
    ```

## 3. Troubleshooting

エラーが発生した場合のゴールデンルール：
**「エラーログを読み解こうとせず、そのままAIに貼り付ける」**

AIはビルドログやコンパイラのエラーメッセージから、文法ミスやリンクエラーを即座に特定し、修正案を提示します。
