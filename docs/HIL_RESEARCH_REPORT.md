# Hardware-in-the-Loop (HIL) Testing Strategy Report

## 1. 概要
本レポートでは、Raspberry Pi Picoの実機を用いた自動テスト（HILテスト）の実現方法をまとめます。
**まず最小構成（PC + Debug Probe + Pico）でのシステム完成を優先**し、将来的なCI/CDパイプライン統合への拡張性を確保します。
特に、**Wokwiシミュレーションとの整合性（Parity）** を最優先し、テストシナリオの共通化を目指します。

## 2. 推奨アーキテクチャ: "Unified Test Runner"

Wokwiのテスト定義 (`blink.test.yaml`) を「正」とし、これを実機でも実行可能な仕組みを構築します。

### 2.1 ハードウェア構成（最小構成）

本プロジェクトでは、まず**最小構成でのシステム完成を優先**します。CI/CDパイプライン統合は将来の拡張として位置づけます。

| 役割 | デバイス | 備考 |
| :--- | :--- | :--- |
| **Development Host** | PC (macOS/Linux/Windows) | OpenOCDとPythonスクリプトを実行。既存の開発環境を利用。 |
| **Debug Probe** | Raspberry Pi Debug Probe | ターゲットへの書き込み・デバッグ・UART通信を担当。CMSIS-DAPv2対応。 |
| **Target Device (DUT)** | Raspberry Pi Pico (RP2040) | テスト対象の実機。 |

**Debug Probe仕様（検証済み）:**
- **インターフェース**: CMSIS-DAPv2
- **ファームウェアバージョン**: 2.0.0
- **デバッグプロトコル**: SWD (Serial Wire Debug)
- **I/O電圧**: 3.3V
- **UART**: Debug Probeは物理UART (GP0 TX / GP1 RX) をUSB CDC経由でPCに転送
  - Pico側: `stdio_uart`有効 (`pico_enable_stdio_uart(blink 1)`)
  - PC側デバイス: `/dev/ttyACM0` (Linux) / `/dev/cu.usbmodemXXXX` (macOS)
- **接続**: 3-pin JST-SH connector（SWD + UART）

**接続図（最小構成）:**
```mermaid
graph LR
    PC[Development PC] -- USB Cable --> Probe[Debug Probe]
    Probe -- 3-pin SWD --> Target[Target Pico]
    Probe -- 3-pin UART --> Target
    Probe -- USB CDC UART --> PC
```

**将来の拡張（オプション）:**
- GitHub Actions Self-hosted Runnerとしての自動化
- 複数ターゲットの並列テスト
- 物理的GPIOテスト配線（現時点ではOpenOCD経由で実現）

### 2.2 ソフトウェア構成（最小構成）
1.  **OpenOCD (v0.12.0以上)**: ファームウェア書き込み・デバッグ用。
    - 検証済み設定: `openocd -f interface/cmsis-dap.cfg -c "transport select swd; adapter speed 1000" -f target/rp2040.cfg`
2.  **pyserial**: UART通信ライブラリ（USB CDC経由で `/dev/ttyACM0` または `/dev/cu.usbmodemXXXX` へアクセス）
3.  **Custom Test Runner (Python)**: `blink.test.yaml` をパースし、実機に対してテストを実行するスクリプト (`hil_runner.py`)。

## 3. Wokwi Parity の実現方法

`wokwi-cli` はシミュレーション専用であり、実機には対応していません。
そのため、**`blink.test.yaml` を解釈して実機を操作するPythonスクリプト (`hil_runner.py`)** を開発することを提案します。

### 3.1 `blink.test.yaml` と実機操作のマッピング

| Wokwi Command | Action on Physical Hardware | Implementation |
| :--- | :--- | :--- |
| `wait-serial: "text"` | UART出力を監視し、指定文字列を待つ | `pyserial` でDebug ProbeのUSB CDC UARTポート (`/dev/ttyACM0`) をRead |
| `expect-pin: {pin: A, value: 1}` | 指定ピンの電圧レベルを確認する | **推奨**: OpenOCD経由でGPIOレジスタを読み取り（配線不要、詳細はSection 4.4） |
| `set-pin: {pin: B, value: 1}` | 指定ピンに電圧を印加する | ❌ **Phase 0-3スコープ外**<br>（Phase 4以降）GPIO制御ボードまたは専用Runner環境で実装 |
| `wait: 1000` | 待機する | `time.sleep(1.0)` |

**注記:** 
- 最小構成では`wait-serial`と`expect-pin`の実装に集中します
- `set-pin`はPhase 4（CI/CD統合）以降で、GPIO制御ボード（Arduino/ESP32等）または専用Runner環境にて実装予定
- `expect-pin`はOpenOCD経由で実装（halt要件あり、詳細はSection 4.4参照）

### 3.2 開発が必要なコンポーネント
*   **`hil_runner.py`**:
    *   YAMLパーサー: `blink.test.yaml` を読み込む。
    *   Serial Handler: Debug Probe USB CDC経由のシリアル通信を管理 (`/dev/ttyACM0` または `/dev/cu.usbmodemXXXX`)。
    *   GPIO Handler: OpenOCD TCP接続でメモリアクセス（レジスタ読み取り）。
    *   OpenOCD Controller: ファームウェアフラッシュと制御を自動化。

## 4. 実現へのステップ

### Phase 0: 手動検証 (Manual Verification) - **Current Focus**
自動化の前に、手動で実機接続とテストロジックの検証を行います。
1.  PCとPicoをUSB接続する。
2.  `blink.uf2` を手動で書き込む。
3.  ターミナルソフトでUART出力を監視し、"LED on/off" のログを確認する。
4.  テスター等でGPIO電圧を確認する。
*目的*: ハードウェアの挙動特性（起動時間、ログ出力タイミング等）を把握し、自動化スクリプトの仕様を固める。

#### 4.1 OpenOCD Debug Probe接続検証 (2025-12-02)

**検証環境:**
- **Host**: macOS
- **Debug Probe**: Raspberry Pi Debug Probe (VID:PID=0x2e8a:0x000c, Serial=XXXXXXXXXXXX)
- **Target**: Raspberry Pi Pico (RP2040)
- **OpenOCD Version**: 0.12.0

##### 4.1.1 初回接続試行（失敗）

**実行コマンド:**
```bash
openocd -f interface/cmsis-dap.cfg
```

**結果:**
```
Open On-Chip Debugger 0.12.0
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Warn : An adapter speed is not selected in the init scripts. OpenOCD will try to run the adapter at the low speed (100 kHz)
Warn : To remove this warnings and achieve reasonable communication speed with the target, set "adapter speed" or "jtag_rclk" in the init scripts.
Warn : could not read product string for device 0x2e8a:0x0003: Operation timed out
Info : Using CMSIS-DAPv2 interface with VID:PID=0x2e8a:0x000c, serial=XXXXXXXXXXXX
Info : CMSIS-DAP: SWD supported
Info : CMSIS-DAP: Atomic commands supported
Info : CMSIS-DAP: Test domain timer supported
Info : CMSIS-DAP: FW Version = 2.0.0
Error: CMSIS-DAP: JTAG not supported
```

**問題点分析:**
1. **Adapter速度未設定**: デフォルトの100 kHzで動作しようとした（警告発生）
2. **JTAGエラー**: RP2040はJTAGをサポートしていない。SWD（Serial Wire Debug）プロトコルの明示的な選択が必要
3. **ターゲット設定欠如**: `target/rp2040.cfg`が未指定のため、チップ固有の初期化が行われない
4. **副次的警告**: `could not read product string for device 0x2e8a:0x0003` - BOOTSELモードのPico（別デバイス）への接続タイムアウト（Debug Probe自体は正常認識）

**Debug Probe検出情報:**
- ✅ CMSIS-DAPv2インターフェースとして正常認識
- ✅ FWバージョン: 2.0.0
- ✅ SWDサポート確認済み
- ✅ Atomic commands サポート
- ✅ Test domain timer サポート

##### 4.1.2 修正後の接続試行（成功）

**実行コマンド:**
```bash
openocd \
  -f interface/cmsis-dap.cfg \
  -c "transport select swd; adapter speed 1000" \
  -f target/rp2040.cfg
```

**結果:**
```
Open On-Chip Debugger 0.12.0
Licensed under GNU GPL v2
For bug reports, read
	http://openocd.org/doc/doxygen/bugs.html
adapter speed: 1000 kHz

Warn : Transport "swd" was already selected
Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Warn : could not read product string for device 0x2e8a:0x0003: Operation timed out
Info : Using CMSIS-DAPv2 interface with VID:PID=0x2e8a:0x000c, serial=XXXXXXXXXXXX
Info : CMSIS-DAP: SWD supported
Info : CMSIS-DAP: Atomic commands supported
Info : CMSIS-DAP: Test domain timer supported
Info : CMSIS-DAP: FW Version = 2.0.0
Info : CMSIS-DAP: Interface Initialised (SWD)
Info : SWCLK/TCK = 0 SWDIO/TMS = 0 TDI = 0 TDO = 0 nTRST = 0 nRESET = 0
Info : CMSIS-DAP: Interface ready
Info : clock speed 1000 kHz
Info : SWD DPIDR 0x0bc12477, DLPIDR 0x00000001
Info : SWD DPIDR 0x0bc12477, DLPIDR 0x10000001
Info : [rp2040.core0] Cortex-M0+ r0p1 processor detected
Info : [rp2040.core0] target has 4 breakpoints, 2 watchpoints
Info : [rp2040.core1] Cortex-M0+ r0p1 processor detected
Info : [rp2040.core1] target has 4 breakpoints, 2 watchpoints
Info : starting gdb server for rp2040.core0 on 3333
Info : Listening on port 3333 for gdb connections
Info : starting gdb server for rp2040.core1 on 3334
Info : Listening on port 3334 for gdb connections
```

**成功要因:**
1. ✅ **SWDトランスポート明示選択**: `-c "transport select swd"` によりRP2040対応プロトコル指定
2. ✅ **Adapter速度設定**: `adapter speed 1000` (1 MHz) で安定した通信速度確保
3. ✅ **RP2040ターゲット設定**: `-f target/rp2040.cfg` によりチップ固有の初期化完了

**ハードウェア検出詳細:**
- **SWD DPIDR**: `0x0bc12477` - ARM Debug Port識別コード
- **DLPIDR**: `0x00000001` (Core 0), `0x10000001` (Core 1) - デバッグリンク識別コード

**プロセッサ検出:**
| Core | プロセッサ | リビジョン | Breakpoints | Watchpoints |
|:-----|:----------|:----------|:------------|:------------|
| rp2040.core0 | Cortex-M0+ | r0p1 | 4 | 2 |
| rp2040.core1 | Cortex-M0+ | r0p1 | 4 | 2 |

**GDBサーバー起動:**
- **Core 0**: `localhost:3333`
- **Core 1**: `localhost:3334`

##### 4.1.3 検証結果のまとめ

**✅ 動作確認項目:**
- [x] Debug ProbeのCMSIS-DAP認識
- [x] SWDインターフェースの初期化
- [x] RP2040デュアルコアの検出
- [x] デバッグ機能（ブレークポイント・ウォッチポイント）の利用可能性
- [x] GDBサーバーの起動

**推奨設定（確定）:**
```bash
openocd \
  -f interface/cmsis-dap.cfg \
  -c "transport select swd; adapter speed 1000" \
  -f target/rp2040.cfg
```

**GDBデバッグセッション例:**
```bash
# ターミナル1: OpenOCD起動
openocd -f interface/cmsis-dap.cfg -c "transport select swd; adapter speed 1000" -f target/rp2040.cfg

# ターミナル2: GDB接続
arm-none-eabi-gdb build/blink.elf
(gdb) target extended-remote localhost:3333
(gdb) load
(gdb) monitor reset init
(gdb) continue
```

**トラブルシューティング知見:**
1. **"JTAG not supported" エラー**: → SWDトランスポートを明示的に選択
2. **Adapter速度警告**: → `adapter speed 1000` (または適切な値) を設定
3. **ターゲット未検出**: → `-f target/rp2040.cfg` を追加
4. **"could not read product string" 警告**: → BOOTSELモードのデバイスが検出されている（Debug Probeの動作には影響なし）

**次のステップ:**
- [ ] ファームウェアのフラッシュ書き込み検証（Phase 0.5）
- [ ] UART経由のシリアル通信確認（Phase 0.6）
- [ ] GPIO テスト戦略の選択と検証（Phase 0.7）
- [ ] エンドツーエンドテストシナリオ検証（Phase 0.8）

#### 4.2 ファームウェアフラッシュ自動化検証 (Phase 0.5) - **Pending**

**目的:**
OpenOCD経由の自動ファームウェア書き込みフローを確立し、CI/CDパイプラインでの利用に向けた検証を行う。

**検証項目:**
1. **フラッシュ書き込みコマンド検証**
   ```bash
   # OpenOCD起動（別ターミナル）
   openocd -f interface/cmsis-dap.cfg -c "transport select swd; adapter speed 1000" -f target/rp2040.cfg
   
   # Telnet経由でフラッシュ（別ターミナル）
   telnet localhost 4444
   > program build/blink.elf verify reset
   > exit
   ```

2. **ワンライナーでのフラッシュ実行**
   ```bash
   openocd -f interface/cmsis-dap.cfg \
     -c "transport select swd; adapter speed 1000" \
     -f target/rp2040.cfg \
     -c "program build/blink.elf verify reset exit"
   ```

3. **エラーハンドリング検証**
   - ファイルが存在しない場合の挙動
   - ターゲット未接続時のエラー処理
   - 書き込み失敗時のリトライロジック

4. **自動化スクリプト作成**
   ```python
   # flash_firmware.py
   import subprocess
   import sys
   
   def flash_firmware(elf_path):
       cmd = [
           "openocd",
           "-f", "interface/cmsis-dap.cfg",
           "-c", "transport select swd; adapter speed 1000",
           "-f", "target/rp2040.cfg",
           "-c", f"program {elf_path} verify reset exit"
       ]
       result = subprocess.run(cmd, capture_output=True, text=True)
       return result.returncode == 0
   ```

**成功基準:**
- [ ] OpenOCD経由でファームウェアが正常に書き込まれる
- [ ] `verify` コマンドでフラッシュ内容が検証される
- [ ] `reset` 後にターゲットが自動的にプログラム実行を開始する
- [ ] Pythonスクリプトから安定して呼び出せる

#### 4.3 UART通信検証 (Phase 0.6) - **Pending**

**目的:**
Debug ProbeのUSB CDC UART機能を使用したシリアル通信とログ収集を検証する。

**検証項目:**
1. **UART デバイス検出**
   ```bash
   # macOS
   ls /dev/cu.usbmodem*
   
   # Linux
   ls /dev/ttyACM*
   ```

2. **手動シリアルモニター接続**
   ```bash
   # screen (macOS/Linux)
   screen /dev/cu.usbmodem14201 115200
   # または
   screen /dev/ttyACM0 115200
   
   # 終了: Ctrl+A, K, Y
   ```

3. **pyserialでのログ収集**
   ```python
   # uart_monitor.py
   import serial
   import sys
   
   def monitor_uart(port, baudrate=115200, timeout=5.0):
       with serial.Serial(port, baudrate, timeout=timeout) as ser:
           print(f"Connected to {port}")
           while True:
               line = ser.readline().decode('utf-8', errors='ignore').strip()
               if line:
                   print(f"[UART] {line}")
                   
   if __name__ == "__main__":
       port = sys.argv[1] if len(sys.argv) > 1 else "/dev/ttyACM0"
       monitor_uart(port)
   ```

4. **パターンマッチング検証**
   ```python
   def wait_for_pattern(ser, pattern, timeout=10.0):
       import time
       start_time = time.time()
       buffer = ""
       
       while time.time() - start_time < timeout:
           if ser.in_waiting:
               chunk = ser.read(ser.in_waiting).decode('utf-8', errors='ignore')
               buffer += chunk
               if pattern in buffer:
                   return True
       return False
   ```

5. **blink.test.yamlシナリオとの整合性確認**
   - `wait-serial: "text"` コマンドの実装が可能か検証
   - タイムアウト処理の妥当性確認
   - 複数パターンの連続検出検証

**成功基準:**
- [ ] Debug ProbeがUSB CDC UARTデバイスとして認識される
- [ ] pyserialで安定してデータ受信できる
- [ ] `stdio_uart` の出力がリアルタイムで取得できる
- [ ] パターンマッチングが正確に動作する
- [ ] タイムアウト処理が適切に機能する

#### 4.4 GPIO テスト戦略 (Phase 0.7) - **Pending**

**背景:**
最小構成では、**OpenOCD経由のGPIOレジスタ読み取りを採用**します。これにより物理的な配線なしでGPIO状態確認が可能になります。

> [!IMPORTANT]
> **重要な制約**: OpenOCDでのメモリ読み取りは**ターゲットの一時停止(halt)が必要**です。これにより、GPIOレジスタ読み取り時にプログラム実行が中断されます。

##### 推奨アプローチ: OpenOCD メモリマップドI/Oアクセス（halt対応）

**概要:**
OpenOCDのTCLインターフェース経由でRP2040のGPIOレジスタ（SIO GPIO_IN）を読み取る。**読み取り時にターゲットをhalt→読み取り→resumeする必要があります。**

**メリット（最小構成に最適）:**
- ✅ **物理配線不要** - Debug Probe接続のみで完結
- ✅ **PC環境に依存しない** - macOS/Linux/Windows全てで同じ実装
- ✅ **セットアップが単純** - 追加ハードウェア不要
- ✅ **状態ベースの検証に適している** - UART同期ポイント後の安定状態確認

**デメリット（重要）:**
- ⚠️ **ターゲットの実行中断が必要** - 読み取り時に一時停止（100-200ms程度）
- ⚠️ ピン電圧を直接測定していない（レジスタ値のみ）
- ⚠️ 実時間のGPIO動作検証には不適

**実装例（halt/resume対応）:**
```python
import socket
import time

def read_gpio_with_halt(host="localhost", port=4444):
    """
    OpenOCD TCL経由でGPIOレジスタ読み取り（halt/resume対応）
    SIO GPIO_IN Register: 0xd0000004 (RP2040 Datasheet Section 2.3.1.7)
    Reference: https://datasheets.raspberrypi.com/rp2040/rp2040-datasheet.pdf
    
    注意: この関数はターゲットを一時停止します！
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((host, port))
        s.recv(1024)  # Welcome message
        
        # ターゲットを停止
        s.sendall(b"halt\n")
        time.sleep(0.1)  # halt完了を待つ
        s.recv(1024)  # halt応答
        
        # GPIO_IN レジスタ読み取り
        cmd = "mdw 0xd0000004\n"
        s.sendall(cmd.encode())
        response = s.recv(1024).decode()
        
        # ターゲットを再開
        s.sendall(b"resume\n")
        s.recv(1024)  # resume応答
        
        # レスポンスをパース
        # 例: "0xd0000004: 02000000"
        value = int(response.split(":")[1].strip().split()[0], 16)
        return value

def check_gpio_bit(gpio_num, expected_value):
    """
    指定GPIOビットの状態確認
    
    Args:
        gpio_num: GPIO番号 (0-29)
        expected_value: 期待値 (0 or 1)
    
    Returns:
        bool: 期待値と一致するか
    """
    gpio_state = read_gpio_with_halt()
    actual_value = (gpio_state >> gpio_num) & 1
    return actual_value == expected_value

# 使用例: GP25 (Internal LED) の状態確認
# 注意: UART出力で同期を取った後に呼び出すこと
is_led_on = check_gpio_bit(25, 1)
```

##### 制限事項と適用範囲

**✅ 適用可能なテストケース:**
- **状態ベースの検証** - UARTメッセージやタイマー後の安定したGPIO状態
- **Blinkテスト** - LED on/off状態の確認
- **シーケンシャルテスト** - ステップごとの状態遷移確認

**❌ 適用不可能なテストケース:**
- **PWM検証** - halt中はPWM停止、デューティ比測定不可
- **高速GPIO切り替え** - halt中断により実時間動作検証不可
- **割り込み駆動GPIO** - halt中は割り込み無効化
- **タイミングクリティカルな動作** - halt遅延（100-200ms）が影響

**Blinkテストでの動作:**
```yaml
steps:
  - wait-serial: 'LED on'      # ← UART同期ポイント（LED状態は安定）
  - expect-pin:                # ← この時点でhalt→読み取り→resume
      part-id: led1            #    LED状態は変化しないため問題なし
      pin: A
      value: 1
```

**重要:** UART出力が同期ポイントとして機能するため、短時間のhaltはBlinkテストには影響しません。

##### 将来の拡張: 物理的GPIO配線（Phase 4+）

実時間GPIO検証やPWM測定が必要な場合は、物理的なGPIO配線によ
る直接電圧測定を検討します。

**実装条件:**
- 専用のテストRunnerマシン（Raspberry Pi等）の導入時
- より厳密なハードウェア検証が必要な場合
- GPIO制御ボード（Arduino/ESP32等）の追加も選択肢

**概要:**
Runner（Raspberry Pi等）のGPIOピンとTarget PicoのGPIOピンを物理的に接続し、`gpiozero`等で電圧レベルを読み取る。

**必要な配線:**
```
Target Pico GP25 (Internal LED) -----> Dedicated Runner GPIO 27 (Input)
Target Pico GND                  -----> Dedicated Runner GND
```

**推奨タイミング:**
- Phase 4 (CI/CD統合) 以降での検討
- 現時点では**優先度低**（最小構成で十分）



### Phase 1: 開発環境セットアップ

既存のPC開発環境に必要なツールをインストールします。

**macOS:**
```bash
# HomebrewでOpenOCDインストール
brew install open-ocd

# Pythonパッケージ
pip3 install pyserial pyyaml

# バージョン確認
openocd --version  # v0.12.0以上推奨
```

**Linux:**
```bash
# aptでOpenOCDインストール
sudo apt update
sudo apt install -y openocd python3 python3-pip

# Pythonパッケージ
pip3 install pyserial pyyaml

# udevルール設定（Debug Probeのアクセス権限）
sudo tee /etc/udev/rules.d/99-debug-probe.rules <<EOF
SUBSYSTEM=="usb", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="000c", MODE="0666"
EOF
sudo udevadm control --reload-rules
```

**Windows:**
```powershell
# ZadigでWinUSBドライバインストールが必要
# OpenOCD: https://github.com/xpack-dev-tools/openocd-xpack/releases/
# Python: https://www.python.org/downloads/

pip install pyserial pyyaml
```

### Phase 2: ハードウェア結線（最小構成）

**必要な接続（3本のケーブルのみ）:**

1.  **USB Cable**: PC ↔ Debug Probe
    - データ通信・OpenOCD制御・電源供給

2.  **3-pin SWD Cable**: Debug Probe ↔ Target Pico
    - Orange (SWDIO) → SWDIO
    - Black (GND) → GND
    - Yellow (SWCLK) → SWCLK

3.  **3-pin UART Cable**: Debug Probe ↔ Target Pico
    - Orange (TX from Probe) → GP1 (UART0 RX on Pico)
    - Black (GND) → GND
    - Yellow (RX to Probe) → GP0 (UART0 TX on Pico)

**物理配線不要:**
- GPIOテストはOpenOCD経由で実現
- PCとTarget Pico間の直接接続は不要

### Phase 3: HIL Test Runner開発（最小構成）

`hil_runner.py` を作成し、PC上で`blink.test.yaml` を実行するロジックを実装。

**主要コンポーネント:**
1.  **YAMLパーサー**: `blink.test.yaml` の読み込み
2.  **OpenOCD Controller**: ファームウェアフラッシュとGPIOレジスタアクセス
3.  **UART Monitor**: USB CDC経由のシリアル通信監視
4.  **Test Orchestrator**: テストシナリオの実行・結果収集

**スクリプト構成例:**
```
hil_runner/
├── __init__.py
├── main.py              # エントリーポイント
├── yaml_parser.py       # YAMLパーサー
├── openocd_client.py    # OpenOCD制御（フラッシュ+GPIOレジスタ）
├── uart_monitor.py      # UART通信
└── test_runner.py       # テストオーケストレータ
```

**実行例:**
```bash
# ローカルPCで実行
cd /path/to/pico-sdk-blink
python3 hil_runner/main.py --test blink.test.yaml --elf build/blink.elf
```

### Phase 4: CI/CD統合（将来拡張）

Phase 0-3の完成後、必要に応じてCI/CDパイプラインへの統合を検討します。

**将来の拡張項目:**
1.  Raspberry Pi 4/5をSelf-hosted Runnerとして構築
2.  GitHub Actions workflowへの統合
3.  自動テスト実行と結果レポート
4.  複数ターゲットの並列テスト
5.  物理的GPIO配線によるハードウェア検証（Option A）

**現時点での優先度:** 低（まずはPhase 0-3の完成を目指す）

## 5. 最適化された結論（最小構成アプローチ）

本プロジェクトでは、**PC + Debug Probe + Target Picoの3デバイス構成**で実機テストシステムを実現します。

**技術的優位性:**
- ✅ **最小限のハードウェア** - 既存のPC開発環境を活用、追加投資不要
- ✅ **物理配線不要** - USB×1本 + SWD/UARTケーブル×2本のみ
- ✅ **OpenOCDベースGPIOテスト** - レジスタアクセスで配線レス実現
- ✅ **クロスプラットフォーム** - macOS/Linux/Windowsで同一実装
- ✅ **検証済み設定** - OpenOCD v0.12.0 + CMSIS-DAPv2の動作確認完了

> [!WARNING]
> **重要な制約事項**
> - OpenOCD GPIO読み取りは**ターゲットの一時停止(halt)が必要**です
> - 読み取り時にプログラム実行が100-200ms中断されます
> - 状態ベースのテスト（Blinkテスト等）には適していますが、実時間GPIO検証やPWM測定には不適です
> - 詳細はSection 4.4「制限事項と適用範囲」を参照してください

**適用範囲:**
- ✅ **Blinkテスト** - UART同期ポイント後のLED状態確認
- ✅ **シーケンシャルテスト** - ステップごとの状態遷移確認
- ✅ **基本的な機能検証** - ファームウェア動作確認
- ❌ **PWM/高速信号検証** - 実時間測定が必要なケースは物理配線が必要（Phase 4+）
- ❌ **`set-pin`コマンド** - GPIO制御はPhase 4以降で実装

**実装フロー:**
```
[Phase 0] 手動検証 → [Phase 1] PC環境セットアップ → [Phase 2] 最小配線 → [Phase 3] Test Runner開発 → [Phase 4] 将来拡張（オプション）
```

**現在の進捗:**
- ✅ Phase 0.1: OpenOCD接続検証（完了）
- ⏳ Phase 0.5: ファームウェアフラッシュ自動化（次のステップ）
- ⏳ Phase 0.6: UART通信検証
- ⏳ Phase 0.7: OpenOCD GPIO テスト実装（halt対応）
- ⏳ Phase 0.8: エンドツーエンドシナリオ検証

この構成により、**「Wokwiでテストシナリオを作成・検証」→「同じシナリオで実機テスト」** という理想的なフローが、最小限のハードウェアとセットアップで実現できます。
ただし、**状態ベースの検証に適用範囲が限定される**ことに留意してください。実時間GPIO検証やより厳密なハードウェア検証が必要な場合は、Phase 4（CI/CD統合）で物理的GPIO配線やGPIO制御ボードの導入を検討します。
将来的にCI/CD統合が必要になった場合でも、Phase 0-3で構築したTest Runnerをそのまま活用できます。

