---
name: pico-i2c-oled
description: >-
  Project-specific bring-up and debugging playbook for the pico-sdk-blink RP2040
  rig (Pico H + CMSIS-DAP Debug Probe + SSD1306 OLED on I2C0 + fx2lafw logic
  analyzer). Use when the OLED is not detected (I2C no devices / i2c_oled=0 /
  all addresses NACK), when the real-time plot shows no data, or when GDB/serial
  behaves oddly on this board. Captures hard-won fixes so they are not
  rediscovered from scratch.
---

> **Provenance: AI-generated.** This is an unofficial, project-local skill
> authored by the Embedder AI agent during a debug session (2026-06-18), not an
> official Embedder skill. Content is distilled from verified observations on
> this rig, but review before relying on it. Edit freely.

# Pico SSD1306 I2C + Logic-Analyzer + Plot bring-up

This rig has recurring, well-understood failure modes. When something on the
I2C/OLED/plot/GDB path misbehaves, follow the matching section below BEFORE
doing a fresh investigation. Most "it worked before" failures here are physical
wiring or tool-contention, not firmware or the MCU.

## Known-good configuration

- **MCU**: RP2040 (Raspberry Pi Pico H). UART stdio @ 115200.
- **Probe**: Raspberry Pi Debug Probe (CMSIS-DAP), `/dev/cu.usbmodem14202`.
- **I2C0**: GP4 (pin 6) = SDA, GP5 (pin 7) = SCL. SSD1306 @ `0x3C`.
- **OLED power**: VCC -> 3V3 (pin 36), NOT VBUS (pin 40 = phantom-power trap). GND common.
- **Logic analyzer**: fx2lafw via sigrok, device `fx2lafw:conn=20.2`.
  - D0 = SCL/GP5, D1 = SDA/GP4, D2 = UART TX/GP0.
- **Toolchain**: ARM GCC + CMake, `PICO_SDK_PATH=/Users/mitokouki/pico-sdk`.
  Build: `PICO_SDK_PATH=... cmake --build build -j4`. Flash via OpenOCD:
  `openocd -f interface/cmsis-dap.cfg -c "transport select swd; adapter speed 1000" -f target/rp2040.cfg -c "program build/blink.elf verify reset exit"`.

## When to invoke

- "I2C no devices" / `i2c_oled=0` / OLED blank, especially after rewiring.
- Real-time plot (Embedder Monitor) shows `Channels (0)` / "no serial data".
- UART silent or GDB leaves the core in bootrom / sleep_ms hangs.
- Wokwi passes but real hardware fails (classic ideal-sim vs real-electrical gap).

## OLED not detected (I2C no devices / all-NACK)

Almost always PHYSICAL (wiring/power), not firmware. Triage in order:

1. **Run the MCU-side check**: `.embedder/hardware/i2c_probe.py`. It confirms
   GP4/GP5 FUNCSEL=3 (I2C), PADS=0x5A (pull-ups on), and bus idles HIGH. If all
   OK, the fault is OFF-CHIP and it prints the next steps.
2. **Analyzer continuity** (the 2026-06-18 root cause): drive GP4/GP5 as plain
   SIO outputs and capture fx2lafw. BOTH D0 (SCL) and D1 (SDA) must show edges.
   A silent line (usually D0/SCL) = open/loose tap -> RESEAT it. I2C SCL and SDA
   always toggle together, so one-line-silent is proof of a physical break.
3. **Power**: OLED VCC must be on 3V3 (pin 36), not VBUS. Reseat VCC/GND if half-inserted.
4. **Firmware is already correct**: scan uses `i2c_write_timeout_us` (write probe
   — the right presence test for write-only SSD1306; a read probe can NACK a
   healthy panel). `ssd1306_init()` has the required `sleep_ms(100)` charge-pump
   settle delay (without it the panel ACKs but stays blank on real hardware).

Verify fix: reset and watch for `I2C device: 0x3C`, `i2c_oled=1`, and
`OLED updated fbcrc=...` changing each cycle.

## Real-time plot shows no data (Channels 0)

Cause: a serial monitor already holds the single CMSIS-DAP CDC stream, so the
plot gets no bytes. It is NOT a parsing/regex problem.

- Tell: `plotStatus` = `Channels (0)` while `serialReadHistory` shows the
  monitor "connected" with thousands of buffered lines + DISCONNECT/CONNECT churn.
- Fix: start the plot, then run `scripts/plot_rebind.sh` (resets the target so
  the boot burst rebinds to the plot). Or start the plot BEFORE any monitor.
- The Teleplot format (`>vsys:<ms>:4.980§V`, `>led:<ms>:1`) needs NO custom
  transform_regex — default `>channel:..:value` parsing works once bytes arrive.
- Export data with `plotStop(export_csv=...)` (see `evidence/latest/plot_telemetry.csv`).

## RP2040 GDB / hang gotchas

- **Halting core1 freezes the timer** (DBGPAUSE): core0's `sleep_ms()` spins
  forever and UART stops. Use a core0-only config for snapshots; resume core1 to recover.
- **GDB flash-probe leaves PC in bootrom** (~0x184) when `gdb_memory_map` is on;
  `gdb_memory_map disable` avoids it. `pc_region=bootrom` in a snapshot => crash/
  unstarted/this gotcha; `flash` => running normally.
- **Bridge OpenOCD vs serial monitor**: the script-bridge OpenOCD can fail to
  launch while a serial monitor holds the port. Run OpenOCD via the shell tool
  with `disconnects_serial: true`, or stop the monitor/plot first.

## Source-level GDB demo

`.embedder/hardware/oled_break.gdb` breaks at `blink.cpp:42` the instant a
device ACKs and prints live `addr`/`ret` (expect `addr=0x3c`, `ret=1`),
the backtrace, and `IC_TX_ABRT_SOURCE` (0 = clean ACK). Drive it with the
managed arm-none-eabi-gdb against an OpenOCD gdb server on :3333.

## References

- `docs/reports/PHASE2_OLED_LOGIC_BRINGUP_REPORT.md` — original bring-up record.
- `docs/guides/HARDWARE_SETUP.md` — I2C/OLED traps (charge pump, phantom power, tap reseat).
- `docs/guides/DEBUGGING_AND_ANALYSIS.md` §5 — plot port-contention.
- Scripts: `.embedder/hardware/i2c_probe.py`, `.embedder/hardware/oled_break.gdb`,
  `.embedder/hardware/gdb_oled_break.py`, `scripts/plot_rebind.sh`.
