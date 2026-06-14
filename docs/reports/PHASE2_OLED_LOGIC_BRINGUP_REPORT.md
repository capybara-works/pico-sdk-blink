# Phase 2 OLED / ロジックアナライザ実機ブリングアップ記録

- **日付**: 2026-06-15
- **対象**: I2C スキャン + SSD1306 (0.96", 128x64, 0x3C) OLED 表示、FX2LP ロジックアナライザによる UART/I2C 実測
- **区分**: Record(実施時点のスナップショット。後から書き換えない)

題材ファームを Lチカから「I2Cスキャン + SSD1306 OLED 表示」へ拡張し、Wokwi
シミュレーションと実機(Pico + Debug Probe + FX2LP ロジアナ)で証拠ベースに検証した。
その過程で複数の「シミュは通るが実機で詰まる」落とし穴を実機で特定・解決した。
再発防止のための恒久ルールは Living 文書へ反映済み(下記「Living文書への反映」)。

## 確定した事実(証拠ベース)

- ロジアナ実測で全配線を確定: **D2→GP0(UART TX), D1→GP4(SDA), D0→GP5(SCL)** すべて正常。
  `logic_uart pass`(LED on/off 復号) + `logic_i2c pass`(Start→Address write:3C→ACK→Data write 復号、0x3C ACK)。
- OLED は最終的に実機で表示成功(`RP2040 PICO LAB` / `I2C OLED OK` / `ADDR 3C FOUND` / `BLINK <n>`)。
- Wokwi シナリオ `blink_i2c.test.yaml` は VCC=3V3 給電でも `I2C device: 0x3C` を検出して pass。

## 詰まった点と解決(時系列)

1. **I2Cが完全に無通信(SCL/SDAトグル0)。**
   原因は新I2C/OLEDファームが未フラッシュで、Picoが旧Lチカを実行していたこと
   (UARTは出るがI2Cは皆無)。`PICO_HARDWARE=1 scripts/flash.sh`(OpenOCD + Debug Probe SWD)で書き込んで解決。
   → 教訓: 「I2C無通信」はまず**ファームが実際に書き込まれているか**を疑う。

2. **短時間キャプチャの取りこぼし。**
   OLED未検出時のI2Cトラフィックは「起動時スキャン + 8サイクル毎(約4秒)の再スキャン」だけになり、
   1秒キャプチャでは取り逃す。**6秒の生キャプチャ**で「本当に信号が来ないのか」を確定。

3. **SCLタップ(D0)の接触不良。**
   症状は「**SDA(D1)は活発にトグル・SCL(D0)はidle-LOWでトグル0**」。
   I2CではSCLとSDAは必ず一緒にトグルするため、これは物理的にSCLタップが
   届いていない証拠。D0をGP5に挿し直して解決し、I2Cデコードが pass。

4. **OLEDがACKするのに画面が真っ黒(最大の罠)。**
   I2Cは電気的に完璧(0x3C ACK + データ書込ACK)でWokwiでは描画も実証済みなのに、
   実機OLEDだけ無表示。`0xA5`(全画素強制点灯・RAM無視)を送る診断ファームで切り分け、
   **初期化直後に `sleep_ms(100)`(チャージポンプ安定待ち)** を追加したら表示成功。
   実機SSD1306はdisplay-on後にチャージポンプが安定するまで描画が見えない。
   **Wokwiは理想モデルでこの待ちが不要なので、シミュは通って実機だけ黒くなる典型**だった。
   修正コミット: `Fix blank SSD1306 on hardware: wait for charge pump`。

5. **電源(VCC)の見落とし候補。**
   「ACKするが無表示」はファントム給電(VCCが浮いていてもI2Cプルアップ経由で
   I2C部だけ動きACKを返すが、表示部の電流が足りず真っ黒)でも起こる。
   VCCは VBUS(USB給電時のみ5Vが来る)より **3V3(OUT, 36番ピン)** が確実。
   Wokwi図も VBUS→3V3 に修正(シミュは引き続き pass)。

## Wokwi 配線図(diagram.json)のコツ

- `pico:GP0 → $serialMonitor:RX` は「GP0=RX」ではなく、**モニタのRX入力へGP0が送る=GP0はTX**。
- ロジアナはOLEDと**同じGP4/GP5に並列タップ**してよい(高インピーダンス)。
- 配線が重なって見えにくい時は、各線を waypoint で「**降下→水平→ピン直上で直角→直下**」に
  整形すると、どのOLEDピンに入るか視認しやすい。座標はキャンバスのスクショから読み取って算出した。

## Living文書への反映(再発防止ルール)

- `docs/guides/HARDWARE_SETUP.md` — 「I2C/OLED 実機ブリングアップの落とし穴」(チャージポンプ待ち・ファントム給電/VCC源)
- `docs/guides/LOGIC_ANALYZER_SETUP.md` — 生トグル診断(`-O bits`)、`conn` 自動選択、≥6秒キャプチャ、SDA活発/SCL沈黙の解釈
