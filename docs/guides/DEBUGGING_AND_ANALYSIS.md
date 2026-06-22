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

### 3.2 実機が止まったように見える時の初動

LED/OLED が点かない、またはファームが動いていないように見える場合は、
再フラッシュや配線変更の前に、次の順で証拠を取ります。

1. UARTを10秒程度取得する:
   ```bash
   PICO_HARDWARE=1 PICO_UART_PORT=/dev/cu.usbmodemXXXX scripts/capture_uart.sh 10
   ```
   `evidence/latest/uart_result.json` の `observations` を見る。
   `led_on` / `led_off` が増えていればファームは生きている。
   `post_i2c_oled_ok`、`oled_updates`、`oled_show_ok` が増え、
   `oled_i2c_errors=0` かつ `bad_markers=0` なら、ファーム側の
   OLED/I2C送信経路は戻り値上正常とみなせる。
   `OLED_RENDER ... fbcrc=...` は内部フレームバッファの証跡であり、
   実画面が光った証拠ではない。実送信は `OLED_SHOW` / `OLED_PAGE` を見る。
   `oled_i2c_retries` が増えて `oled_i2c_retry_fail=0` の場合は、
   一時的なNACK/timeoutをリトライで回復した状態として記録する。
2. UARTが無音、または1バイト程度しか出ない場合は、書き込みではなくDebug Probeで
   ターゲットを再起動し、直後のPOSTを取り直す:
   ```bash
   PICO_HARDWARE=1 scripts/reset_target.sh
   PICO_HARDWARE=1 PICO_UART_PORT=/dev/cu.usbmodemXXXX scripts/capture_uart.sh 10
   ```
   OpenOCDが `lockup` / `double fault` を出しても、再起動後のUARTで
   `health_hint=oled_i2c_ok` まで戻れば、まず一過性のターゲット停止として扱う。
   `health_hint=uart_nul_only` の場合は、Debug ProbeのUSBシリアル観測経路だけが
   NULを返している可能性が高い。GDBで `pc_region=flash` かつfaultなし、
   またはロジックアナライザUARTで `LED on` / `POST` が読めるなら、
   ファーム停止ではなくUART観測経路の問題として扱う。
3. UARTは動くが `i2c_oled=0` / `I2C no devices` が出る場合は、
   ファームや再フラッシュより先に [HARDWARE_SETUP.md](HARDWARE_SETUP.md) の
   I2C/OLED切り分けを使う。`I2C recovery done sda=1 scl=1` の後も
   100kHz/50kHz両方で `I2C no devices` なら、バスはHighへ復旧できている。
   MCU側レジスタも正常なら、再フラッシュではなくオフチップ配線/給電を見る。
   `sda=0` または `scl=0` の場合は、対象ラインが外部でLow保持されている。
   `oled_probe_nack` が増え `oled_probe_ack=0` の場合も、0x3Cまで到達して
   OLEDがACKしていない状態として扱う。
   `health_hint=oled_sda_pullup_missing` なら、SCL側の外部pull-upは見えているが
   SDA側だけ見えていない。これはSDA線/端子/ブレッドボード列だけでなく、
   OLEDモジュール上のpull-up、OLEDの給電/GND、SDA入力保護、
   コントローラ状態/故障も含む「Pico外のSDA経路」問題として扱う。
4. より深く見る必要がある場合だけGDBスナップショットを取る:
   ```bash
   PICO_HARDWARE=1 scripts/gdb_snapshot.sh
   ```
   `pc_region=flash`, `fault.exception_number=0`, `target_resumed=true` が
   通常動作中の目安。GDBは短時間core0をhaltするため、取得後のUART再確認まで行う。

この順序を守ると、見た目だけで「実機が死んだ」「OLED配線が悪い」
「ファームを書き直すべき」と早合点することを避けられます。

### 3.3 静的解析との連携 (Crash/Hang Analysis Workflow)
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

**原因**: 同じポート (例: `/dev/cu.usbmodemXXXX`, CMSIS-DAP の CDC UART) を
**シリアルモニタが既に占有**している。モニタとプロットは1本のCDCストリームを
取り合うため、後発のプロットにバイトが届かない。`plotStatus` が `Channels (0)` で
かつ `serialReadHistory` がモニタ "connected" + 大量バッファ + DISCONNECT/CONNECT
の往復を示していれば、これは**2リーダー競合**であり、パース/正規表現の問題ではない。

**対処（実績あり）**:
1. `plot_start` の後にゲート付きユーティリティでターゲットをリセットする:
   `PICO_HARDWARE=1 scripts/plot_rebind.sh`
   リブート直後のバースト出力が最新サブスクライバ（プロット）に再バインドし、
   チャネルが即座に出現する。
2. もしくは**プロットを先に**起動してからモニタを開く（プロットが先にバインド）。

**補足**: このTeleplot形式に `transform_regex` は不要。バイトさえ届けば
既定の `>channel:..:value` パースで通る。`plotStop(export_csv=...)` で
`timestamp_ms/channel/value/unit` 形式のCSVを書き出せる
（サンプル: `evidence/latest/plot_telemetry.csv`）。
