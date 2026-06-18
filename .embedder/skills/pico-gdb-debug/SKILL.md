---
name: pico-gdb-debug
description: >-
  GDB and SWD register debugging on the pico-sdk-blink RP2040 via OpenOCD +
  CMSIS-DAP. Use for source-level breakpoints, reading C variables/backtraces,
  peeking RP2040 registers (IO_BANK0/PADS/I2C0), or diagnosing hangs and the
  known RP2040 debug gotchas (core1 timer freeze, bootrom flash-probe).
---

> **Provenance: AI-generated.** This is an unofficial, project-local skill
> authored by the Embedder AI agent during a debug session (2026-06-18), not an
> official Embedder skill. Content is distilled from verified observations on
> this rig, but review before relying on it. Edit freely.

# GDB / SWD debug on RP2040 (OpenOCD + CMSIS-DAP)

## Start a gdb server and attach

OpenOCD listens on :3333 (core0) and :3334 (core1). Managed gdb:
`/Users/mitokouki/.embedder/tools/gdb/.../arm-none-eabi-gdb-py3`.

```sh
openocd -f interface/cmsis-dap.cfg -c "transport select swd; adapter speed 1000" -f target/rp2040.cfg -c "init" &
arm-none-eabi-gdb-py3 build/blink.elf -batch -x .embedder/hardware/oled_break.gdb
```

Reusable scripts: `.embedder/hardware/oled_break.gdb` (breaks at the I2C ACK and
prints live `addr`/`ret`/backtrace) and `.embedder/hardware/i2c_probe.py`
(register-level pin/bus check via the script bridge).

## Quick register peeks (no firmware symbols needed)

```sh
openocd ... -c "init" -c "reset run" -c "sleep 1500" -c "halt" \
  -c "mdw 0x40014024" -c "mdw 0x4001402c"   # GP4/GP5 CTRL: FUNCSEL bits 0..4 (3=I2C)
  -c "mdw 0x4001c014" -c "mdw 0x4001c018"   # PADS GP4/GP5: 0x5A = pull-up on
  -c "mdw 0xd0000004"                        # SIO_GPIO_IN: bit4=SDA bit5=SCL live level
  -c "mdw 0x40044080" -c "exit"              # I2C0 IC_TX_ABRT_SOURCE: 0 = clean ACK
```

Use the `register_lookup` tool against the RP2040 SVD to confirm addresses/fields.

## Source-level breakpoint pattern

```
break blink.cpp:42      # only reached when i2c_write returns >=0 (an ACK)
continue
print/x addr            # expect 0x3c
print ret               # expect 1 (one byte written = ACKed)
backtrace               # scan_i2c_bus <- main
```

## RP2040 debug gotchas (confirmed on this rig)

- **Halting core1 freezes the timer (DBGPAUSE)**: core0 `sleep_ms()` spins forever
  and UART stops. Use a core0-only target config for snapshots; resume core1 to recover.
- **GDB flash-probe leaves PC in bootrom (~0x184)** when `gdb_memory_map` is enabled;
  `gdb_memory_map disable` avoids it. `pc_region=bootrom` => crash/unstarted/this gotcha;
  `flash` => running normally; `sram` => RAM code.
- **Macros aren't symbols**: `print SSD1306_I2C_ADDR` fails (it's a `#define`). Use the
  literal value or compare against `addr` directly.
- **Probe contention**: the script-bridge OpenOCD can fail to launch while a serial
  monitor holds the port. Run OpenOCD via the shell tool with `disconnects_serial: true`,
  or stop the monitor/plot first.

## References

- `scripts/gdb_snapshot.sh` (core0-only snapshot with the fixes above).
- `docs/guides/DEBUGGING_AND_ANALYSIS.md`, `docs/guides/HARDWARE_SETUP.md`.
