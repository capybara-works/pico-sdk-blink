# デバッグ・解析ガイド (Debugging and Analysis Guide)

## 1. 概要
本プロジェクトでは、ビルドプロセスに高度な静的解析ツールの実行を統合しており、生成されたバイナリの詳細な検証が可能です。
これにより、デバッガを接続できない環境や、事後的なクラッシュ解析においても、ソースコードレベルでの追跡が可能となっています。

## 2. ソースコード付き逆アセンブル (Source-Interleaved Disassembly)

### 2.1 概要
ビルドプロセス (`cmake --build`, `scripts/build_firmware.sh`, または `scripts/build.sh`) の完了後、自動的に以下のファイルが生成されます。

*   **ファイルパス**: `build/blink.S.dis`
*   **生成ツール**: `arm-none-eabi-objdump -S`

このファイルは、C/C++のソースコードと、それに対応して生成されたアセンブリ命令を交互に配置（インターリーブ）したものです。

### 2.2 何が可能になったか (Capabilities)

このファイルの生成自動化により、以下の解析が即座に可能となりました。

#### A. コンパイラ最適化の検証
ソースコードが実際にどのような機械語に変換されたかを確認できます。
*   **インライン展開の確認**: 関数呼び出しが実際にインライン化されているか。
*   **ループ最適化**: ループが展開されているか、不要な処理が削除されているか。
*   **揮発性変数の扱い**: `volatile` 修飾子が正しく機能し、メモリアクセスが省略されていないか。

#### B. クラッシュアドレスの特定 (Crash Dump Analysis)
実行時に例外が発生し、プログラムカウンタ (PC) のアドレスしか判明していない場合でも、このファイルを参照することで、**「どのソースコード行の、どの命令でクラッシュしたか」**をピンポイントで特定できます。

#### C. 低レイヤー動作の理解
C++の抽象的な記述（クラス、テンプレートなど）が、実際のハードウェア上でどのようなコスト（命令数、メモリ操作）を伴うかを可視化できます。

### 2.3 活用例

**ソースコード:**
```c
gpio_init(LED_PIN);
```

**`blink.S.dis` での出力例:**
```asm
  gpio_init(LED_PIN);
100002de:       2019            movs    r0, #25
100002e0:       f000 f832       bl      10000348 <gpio_init>
```
このように、`gpio_init` 関数を呼び出すために、レジスタ `r0` に `25` (LED_PIN) をセットし、分岐命令 `bl` を実行していることが一目で分かります。

## 3. 実行時解析 (Runtime Analysis)

### 3.1 GDBスナップショット
実機が接続されている場合、`scripts/gdb_snapshot.sh` で動作中のターゲットから
PC/LR/SP/xPSR とシンボル解決済みバックトレースを取得できます
（結果: `evidence/latest/gdb_snapshot.json`）。

`pc_region` フィールドが一次診断材料になります:
*   `bootrom` (< 0x10000000): クラッシュ、未起動、またはデバッガ起因の停止
    （`docs/guides/HARDWARE_SETUP.md` の「既知の落とし穴」参照）
*   `flash`: 通常のコード実行中
*   `sram`: RAM実行コード

### 3.2 静的解析との連携 (Crash/Hang Analysis Workflow)
PCアドレスしか分からない場合でも、`blink.S.dis` と組み合わせて原因を特定できます。

実例（2026-06-12, `docs/reports/AGENT_LAB_PHASE1_REPORT.md`）:
ターゲットのUARTが沈黙 → スナップショットで PC=0x10000d92 を取得 →
`grep "10000d92:" build/blink.S.dis` で `sleep_ms` 内のタイマーポーリングと特定 →
PCが時間をおいても不動であることから「タイマーが進んでいない」と推定 →
RP2040 の DBGPAUSE によるタイマー凍結（core1がhaltしたまま）を突き止めた。

## 4. その他の解析ツール

### 4.1 セクションヘッダ情報の確認
`blink.elf` に対して `objdump -h` を実行することで、メモリレイアウト（各セクションの配置アドレスとサイズ）を確認できます。これは、スタックオーバーフローやメモリ不足の調査に役立ちます。

## 5. リアルタイムプロット (Embedder Monitor) の落とし穴

ファームウェアは Teleplot 形式のテレメトリを UART に出力します
（例: `>vsys:<ms>:4.980§V`, `>die_temp:<ms>:25.26§°C`, `>led:<ms>:1`）。
`sample_and_report()`（`blink.cpp`）が毎サイクル送出します。

### 5.1 「Channels (0) / no serial data received」になる(2026-06-18 確認)

**症状**: ファームは明らかにTeleplot行を流しているのに、プロット側は
`Channels (0)` のまま、または `No serial data received yet` と表示される。

**原因**: 同じポート (`/dev/cu.usbmodem14202`, CMSIS-DAP の CDC UART) を
**シリアルモニタが既に占有**している。モニタとプロットは1本のCDCストリームを
取り合うため、後発のプロットにバイトが届かない。`plotStatus` が `Channels (0)` で
かつ `serialReadHistory` がモニタ "connected" + 大量バッファ + DISCONNECT/CONNECT
の往復を示していれば、これは**2リーダー競合**であり、パース/正規表現の問題ではない。

**対処（実績あり）**:
1. `plot_start` の後に OpenOCD でターゲットをリセットする:
   `openocd -f interface/cmsis-dap.cfg -c "transport select swd; adapter speed 1000" -f target/rp2040.cfg -c "init; reset run; exit"`
   リブート直後のバースト出力が最新サブスクライバ（プロット）に再バインドし、
   チャネルが即座に出現する。
2. もしくは**プロットを先に**起動してからモニタを開く（プロットが先にバインド）。

**補足**: このTeleplot形式に `transform_regex` は不要。バイトさえ届けば
既定の `>channel:..:value` パースで通る。`plotStop(export_csv=...)` で
`timestamp_ms/channel/value/unit` 形式のCSVを書き出せる
（サンプル: `evidence/latest/plot_telemetry.csv`）。
