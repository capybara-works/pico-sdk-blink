# ハードウェアセットアップ (Hardware Setup)

実機HILテストに必要な接続をまとめます。配線の正はこの文書を基準にしてください。
詳細な調査経緯は [HIL_RESEARCH_REPORT.md](../reports/HIL_RESEARCH_REPORT.md) と
[HARDWARE_INTEGRATION_TEST_REPORT.md](../reports/HARDWARE_INTEGRATION_TEST_REPORT.md) を参照できますが、
`docs/reports/` は過去時点の記録であり、現在のOLED/I2C配線手順ではありません。

## 構成要素

- **Raspberry Pi Pico** (RP2040) — テスト対象。オンボードLED (GP25) を使用
- **Raspberry Pi Debug Probe** (CMSIS-DAPv2) — SWD書き込み + UART中継
- **FX2LP系 USBロジックアナライザ** — [LOGIC_ANALYZER_SETUP.md](LOGIC_ANALYZER_SETUP.md) 参照

## 接続

```text
PC ──USB── Debug Probe ──SWD(3pin)── Pico (SWDIO/SWCLK/GND)
                       └─UART(3pin)── Pico (GP0=TX → Probe RX, GP1=RX ← Probe TX, GND)
PC ──USB── Logic Analyzer ──────────── Pico (D2 → GP0/TX, GND → GND)
Pico ──I2C── SSD1306 OLED (GP4=SDA, GP5=SCL, 3V3, GND)
```

1. PC ↔ Debug Probe: USBケーブル
2. Debug Probe "D"コネクタ ↔ Pico SWDピン (SWCLK / GND / SWDIO)
3. Debug Probe "U"コネクタ ↔ Pico UART0 (GP0/GP1/GND)
4. ロジックアナライザ ↔ Pico UART0 TX (Debug ProbeのUART配線は外さず並列接続)

### 現在の題材ファームの正配線

Picoの**40ピンヘッダの物理ピン番号**、Debug Probeの3pinコネクタ、
OLEDモジュールのシルク印字、ロジックアナライザのD0/D1/D2は別の番号体系です。
配線時は下表を単一の基準にしてください。

| 対象 | Pico側 | 相手側 | 用途 |
|---|---|---|---|
| Debug Probe UART RX | Pin 1 / GP0 / UART0 TX | Debug Probe Uコネクタ RX | PicoのUARTログ送信 |
| Debug Probe UART TX | Pin 2 / GP1 / UART0 RX | Debug Probe Uコネクタ TX | PicoへのUART受信 |
| Debug Probe UART GND | Pin 3 / GND | Debug Probe Uコネクタ GND | UART基準GND |
| SSD1306 OLED SDA | Pin 6 / GP4 | OLED端子 `SDA` | I2C data |
| SSD1306 OLED SCL | Pin 7 / GP5 | OLED端子 `SCL` | I2C clock |
| SSD1306 OLED GND | 任意のPico GND | OLED端子 `GND` | OLED電源GND |
| SSD1306 OLED VCC | Pin 36 / 3V3(OUT) | OLED端子 `VCC` | OLED電源 |
| ロジアナUART | Pin 1 / GP0 / UART0 TX | D2 / CH2 | UART TX観測。Debug Probeと並列可 |
| ロジアナI2C SCL | Pin 7 / GP5 / SCL | D0 / CH0 | I2C SCL観測。OLEDと並列 |
| ロジアナI2C SDA | Pin 6 / GP4 / SDA | D1 / CH1 | I2C SDA観測。OLEDと並列 |
| ロジアナGND | 任意のPico GND | GND | ロジアナ基準GND |

OLEDモジュール側のピン順は製品によって `GND/VCC/SCL/SDA`、
`VCC/GND/SCL/SDA`、`GND/VCC/SDA/SCL` などがあり得ます。
色や並び順ではなく、必ずモジュール基板上の `VCC` / `GND` / `SCL` / `SDA`
印字を優先してください。

| ロジックアナライザ | Pico | 用途 |
|---|---|---|
| GND | Pin 3 / GND | 信号基準。Debug ProbeのGNDと共通 |
| D2 / CH2 | Pin 1 / GP0 / UART0 TX | `LED on` / `LED off` のUART TX観測 |

ファームウェアはUART0 (115200 baud) に `LED on` / `LED off` とI2Cスキャン結果を
出力します(CMakeLists.txt で `pico_enable_stdio_uart(blink 1)`)。
`blink.test.yaml` の最小UART HILだけなら、I2Cデバイスやロジックアナライザの
I2C配線は必須ではありません。OLED表示や `PICO_LOGIC_I2C=1` の実測では、
上表のSSD1306 OLED配線とロジアナI2C配線を使います。

## ツールのインストール

```bash
# macOS
brew install open-ocd
pip3 install -r requirements-hil.txt

# Linux
sudo apt install openocd python3-pip
pip3 install -r requirements-hil.txt
```

## ローカル設定

ポート等の環境依存値はGit管理しません。テンプレートをコピーして編集してください。

```bash
cp config/hardware.example.yaml config/hardware.local.yaml
# UARTポートを確認して serial.port に設定
ls /dev/cu.usbmodem*   # macOS
ls /dev/ttyACM*        # Linux
```

または環境変数で渡します。

```bash
export PICO_UART_PORT=/dev/cu.usbmodem14402
```

## 動作確認

```bash
PICO_HARDWARE=1 scripts/verify_all.sh  # 検証ループ全体(推奨。実機操作の明示的有効化が必要)
# または個別に
scripts/build.sh        # ビルド
PICO_HARDWARE=1 scripts/flash.sh        # OpenOCD経由で書き込み
PICO_HARDWARE=1 scripts/capture_uart.sh # UARTログ取得 → evidence/latest/uart.log
PICO_HARDWARE=1 scripts/run_hil.sh      # E2E HILテスト → evidence/latest/hil_result.json
PICO_HARDWARE=1 scripts/gdb_snapshot.sh # レジスタ+バックトレース → evidence/latest/gdb_snapshot.json
PICO_LOGIC_UART=1 scripts/capture_logic_uart.sh 3000 # ロジアナD2でUART TXを実測
```

実機未接続の場合、これらは明示的に fail または skip を返します(偽の成功にはなりません)。

## 実機が動いていないように見える時の初動

見た目のLED/OLEDだけで判断せず、まずログで状態を分けます。配線変更や再フラッシュは、
UART/GDB証拠で必要性が見えてから行ってください。

```bash
PICO_HARDWARE=1 PICO_UART_PORT=/dev/cu.usbmodemXXXX scripts/capture_uart.sh 10
cat evidence/latest/uart_result.json
```

`uart_result.json` の目安:

- `observations.led_on` / `observations.led_off` が増える: ファームは実行中。
- `observations.post_i2c_oled_ok` と `observations.oled_updates` が増える:
  OLED/I2Cはファーム側で検出・描画更新を試みている。
- `observations.oled_show_ok` が増え、`observations.oled_i2c_errors=0`:
  SSD1306へのページ転送はI2C戻り値上成功している。画面が白化/無反応なら
  パネル側の表示モード、チャージポンプ、給電、近縁コントローラ差異を疑う。
- `observations.oled_i2c_retries` が増え、`observations.oled_i2c_retry_fail=0`:
  一度NACK/timeoutしたI2C書き込みがリトライで成功している。継続的な異常ではないが、
  接触や立ち上がりの不安定さを見るために記録する。
- `observations.oled_probe_nack` が増え、`observations.oled_probe_ack=0`:
  0x3Cへ到達しているがOLEDがACKしていない。Pico側I2CよりOLED側の接触/給電を優先する。
- `health_hint=oled_sda_pullup_missing`:
  Pico側から見てSCLには外部pull-upが見える一方、SDAには見えていない。
  これは「SDAの期待経路がPicoから電気的に見えていない」ことを示す。
  SDA線/端子/ブレッドボード列だけでなく、OLEDモジュール上のpull-up、
  OLEDの給電/GND、SDA入力保護、コントローラ状態/故障も候補に含める。
- `health_hint=oled_i2c_ok` かつ `observations.bad_markers=0`: LED/OLED経路はログ上正常。
- `health_hint=uart_nul_only`:
  Debug ProbeのUSBシリアル経路ではNULだけが見えている。
  この状態だけでファーム停止とは判断せず、`scripts/gdb_snapshot.sh` か
  `PICO_LOGIC_UART=1 scripts/capture_logic_uart.sh` で実行状態を裏取りする。
- `health_hint=uart_silent`: Debug Probe UART、ターゲット停止、またはポート設定を疑う。

UARTが沈黙する場合は、まず `PICO_HARDWARE=1 scripts/reset_target.sh` で再起動し、
同じUART確認をやり直します。再起動後に `health_hint=oled_i2c_ok` へ戻るなら、
再フラッシュや配線変更よりも一過性のターゲット停止として記録します。

## RP2040デバッグの既知の落とし穴(実機で確認済み)

`scripts/gdb_snapshot.sh` は以下の問題を回避しています。同様の症状を診断する際の参考:

1. **core1をhaltするとアプリが死んだように見える。**
   RP2040のTIMERはDBGPAUSE機構により「いずれかのコアがデバッグhalt中」は停止する。
   core1がhaltしたまま残ると、core0の `sleep_ms()` はタイマーポーリング
   (`timer_time_reached`)で永遠にスピンし、UART出力が止まる。デフォルトの
   `target/rp2040.cfg`(2コア構成)でGDBをpipe接続すると core1 に繋がることが
   あるため、スナップショットでは `set USE_CORE 0` でcore0単独構成にする。
   復旧は core1 を resume するだけでよい(リセット不要)。

2. **GDB接続時のフラッシュプローブが実行状態を破壊する。**
   `gdb_memory_map` が有効(デフォルト)だと、GDB接続時にOpenOCDがターゲット
   CPU上でフラッシュプローブのアルゴリズムを実行し、コアをブートROM内の
   ブレークポイント(PC≈0x184)に置き去りにする。`gdb_memory_map disable` で回避。

3. **PCのアドレス領域が最初の診断材料になる。**
   `gdb_snapshot.json` の `pc_region` を参照: `bootrom`(<0x10000000)は
   クラッシュ/未起動/上記1・2の症状、`flash` は正常実行中、`sram` はRAM実行コード。

## I2C/OLED 実機ブリングアップの落とし穴(実機で確認済み)

SSD1306 OLED を実機で表示させる際に詰まった点。詳細な記録は
[../reports/PHASE2_OLED_LOGIC_BRINGUP_REPORT.md](../reports/PHASE2_OLED_LOGIC_BRINGUP_REPORT.md)。

1. **OLEDがI2C ACKを返すのに画面が真っ黒 → チャージポンプ安定待ち。**
   実機SSD1306は display-on 後にチャージポンプが安定するまで描画が見えない。
   初期化シーケンスの最後に `sleep_ms(100)` を入れる(`ssd1306_min.h` 実装済み)。
   **Wokwiは理想モデルでこの待ちが不要なため、シミュは通って実機だけ黒くなる**。
   切り分けには `0xA5`(全画素強制点灯・RAM無視)を送ってパネル自体が光るか確認する。

2. **「ACKするが無表示」はファントム給電も疑う。**
   VCCが浮いていても、I2Cプルアップ(3.3V)がSDA/SCLの保護ダイオード経由で
   回り込み、I2C部だけ動いてACKを返すことがある(表示部の電流は足りず真っ黒)。
   OLEDのVCCは **VBUS(ターゲットがUSB給電されている時のみ5V)** より
   **3V3(OUT, 36番ピン)** が確実。VCC/GNDの挿し込みが半挿しでないかも確認。

3. **OLEDが本当に表示しないのか、ファームが未フラッシュなのかを先に切り分ける。**
   I2Cが完全に無通信なら、まず新ファームが実際に書き込まれているかを疑う
   (UARTは出るがI2Cが皆無 = 旧ファーム実行中の典型)。

4. **ロジアナでI2C片線が見えない時は、観測経路とオフチップ異常を分ける。**
   以前の再配線後トラブルでは、**D0/SCL(GP5)** の観測経路が見えず、
   全アドレスがNACKになった。MCU側は完全に正常(ピンmux=I2C・プルアップON・
   バスidle-HIGH)なので、レジスタを見るだけでは原因が「Pico外」と判るだけ。
   **高速切り分け**: `.embedder/hardware/i2c_probe.py` を実行するとMCU側を
   一括判定する。MCU側が健全なら、GP4/GP5をGPIO出力でトグルしながら
   ロジアナをキャプチャし、**D0(SCL)とD1(SDA)の両方にエッジが出るか**を見る。
   片方(通常D0/SCL)が沈黙する場合、ロジアナの設定チャンネルがその信号を見られていない。
   タップ接触、チャンネル割り当て違い、ロジアナ入力不良、またはOLED/ブレッドボード側の
   電気的異常を順に切り分ける。

5. **`I2C recovery done sda=1 scl=1` でも全NACK → 次はOLED側の給電/経路/モジュール状態。**
   ファームはOLED未検出時に、SCLを9クロック送ってSTOP条件を生成し、
   100kHzと50kHzで再スキャンする。復旧ログでSDA/SCLが両方Highに戻り、
   OpenOCDレジスタでもGP4/GP5がI2C・pull-up有効・idle-HIGHなら、
   Pico側のI2C設定やバス詰まりではなく、OLEDモジュールがACKしていない。
   その場合は再フラッシュを繰り返すより、OLEDの **VCC=3V3(36番ピン)**、
   **GND共通**、**SDA=GP4**、**SCL=GP5** の電気的経路、モジュール上pull-up、
   OLEDコントローラの異常状態/破損を確認する。
   Picoの `vsys_est_mv` が正常でも、OLEDのVCCに電気が来ている保証にはならない。

6. **白化は「画面の見た目」と「I2C送信結果」を分けて記録する。**
   `OLED_RENDER ... fbcrc=...` はPico内部のフレームバッファCRCであり、
   実パネルが受信・表示した証拠ではない。白化前/白化中/白化後で
   `OLED_SHOW result=ok pages_ok=8 pages_fail=0` が維持されるなら、
   I2C転送より表示モード(`0xA4`/`0xA6`/`0xA5`)、チャージポンプ、給電、
   SSD1306近縁コントローラ差異を疑う。`OLED_I2C_ERROR` や
   `OLED_PAGE ... ok=0` が出るなら、I2C ACK/配線/電源安定性を優先して見る。

7. **白化後に全NACKへ移行した場合は、単なる表示モード異常より深く見る。**
   触っていない状態で「正常表示 → 徐々に白化 → 再投入後OLEDだけ沈黙」と進んだ場合、
   `0xA4`/`0xA6` などの表示モード復旧で戻る一過性異常だけでなく、
   OLEDの電源投入順序、チャージポンプ、モジュール上のpull-up、SDA/SCL入力保護、
   SSD1306近縁コントローラ差異、モジュール故障を候補に入れる。
   `LIVE sda_pu=0 scl_pu=1 ack3c=0` が継続する場合、少なくともPicoから見た
   SDA側の外部pull-up/ACK経路は復旧していない。

> **教訓**: 「Wokwiは通るのに実機だけNG」かつ「全アドレスNACK」は、
> Pico内のファームやI2C設定より先に、Pico外の電気的経路、給電、OLEDモジュール状態を
> 優先して切り分ける。まず `i2c_probe.py` でMCU側を除外し、ロジアナで両ラインの
> 観測可否を確認する。

## ロジックアナライザ

UART/I2C/SPIの物理層観測用に、FX2LP系USBロジックアナライザを使用します。
実測は `PICO_LOGIC_UART=1` / `PICO_LOGIC_I2C=1`、または全capture用の
`PICO_LOGIC_ANALYZER=1` を明示した場合のみ行います。
チャネル割り当ては `config/hardware.example.yaml` の `logic_analyzer.channels` を参照。

確認済みのロジアナ実測構成は **GND(必須) + D2→GP0/TX + D0→GP5/SCL + D1→GP4/SDA** で、
`PICO_LOGIC_ANALYZER=1`(UART + I2C 同時実測)で `logic_uart` / `logic_i2c` とも
pass を確認済み(2026-06-15)。配線・診断のコツは
[LOGIC_ANALYZER_SETUP.md](LOGIC_ANALYZER_SETUP.md) を参照。
