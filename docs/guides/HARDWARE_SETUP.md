# ハードウェアセットアップ (Hardware Setup)

実機HILテストに必要な接続をまとめます。詳細な調査経緯は
[HIL_RESEARCH_REPORT.md](../reports/HIL_RESEARCH_REPORT.md) と
[HARDWARE_INTEGRATION_TEST_REPORT.md](../reports/HARDWARE_INTEGRATION_TEST_REPORT.md) を参照してください。

## 構成要素

- **Raspberry Pi Pico** (RP2040) — テスト対象。オンボードLED (GP25) を使用
- **Raspberry Pi Debug Probe** (CMSIS-DAPv2) — SWD書き込み + UART中継
- **(将来) FX2LP系 USBロジックアナライザ** — [LOGIC_ANALYZER_SETUP.md](LOGIC_ANALYZER_SETUP.md) 参照

## 接続

```text
PC ──USB── Debug Probe ──SWD(3pin)── Pico (SWDIO/SWCLK/GND)
                       └─UART(3pin)── Pico (GP0=TX → Probe RX, GP1=RX ← Probe TX, GND)
```

1. PC ↔ Debug Probe: USBケーブル
2. Debug Probe "D"コネクタ ↔ Pico SWDピン (SWCLK / GND / SWDIO)
3. Debug Probe "U"コネクタ ↔ Pico UART0 (GP0/GP1/GND)

ファームウェアはUART0 (115200 baud) に `LED on` / `LED off` を出力します
(CMakeLists.txt で `pico_enable_stdio_uart(blink 1)`)。

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
```

実機未接続の場合、これらは明示的に fail または skip を返します(偽の成功にはなりません)。

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

## 将来: ロジックアナライザ

UART/I2C/SPIの物理層観測用に、安価なFX2LP系USBロジックアナライザの接続を予定しています。
チャネル割り当ての想定は `config/hardware.example.yaml` の `logic_analyzer.channels` を参照。
