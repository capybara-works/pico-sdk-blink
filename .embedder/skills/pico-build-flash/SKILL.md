---
name: pico-build-flash
description: >-
  Build and flash the pico-sdk-blink RP2040 firmware with the exact toolchain,
  paths, and OpenOCD/CMSIS-DAP commands that work on this rig. Use when asked to
  build, flash, or program the Pico, or when a build/flash command fails with
  missing PICO_SDK_PATH or probe errors.
---

> **Provenance: AI-generated.** This is an unofficial, project-local skill
> authored by the Embedder AI agent during a debug session (2026-06-18), not an
> official Embedder skill. Content is distilled from verified observations on
> this rig, but review before relying on it. Edit freely.

# Build & flash the Pico (RP2040 + CMSIS-DAP)

Known-good workflow for this project. Prefer the repository scripts because
they preserve evidence and enforce the hardware safety gates. Treat raw
OpenOCD/CMake commands below as manual fallback notes only.

## Environment

- `PICO_SDK_PATH` must point at the Pico SDK (this rig has used `/Users/mitokouki/pico-sdk`).
- ARM GCC, CMake, OpenOCD all on PATH.
- Probe: Raspberry Pi Debug Probe (CMSIS-DAP). UART port is local state:
  use `PICO_UART_PORT` or `config/hardware.local.yaml`, not hard-coded paths.
- Build dir: `build/`. Targets: `build/blink.elf`, `build/blink.uf2`, `build/blink.bin`.

## Build with evidence

```sh
scripts/build.sh
```

Expected: build + CTest pass, and optional Wokwi runs when `WOKWI_CLI_TOKEN` is set.

## Flash (OpenOCD + SWD)

Hardware actions require explicit human intent. Use:

```sh
PICO_HARDWARE=1 scripts/flash.sh
```

Then capture UART through the gated wrapper:

```sh
PICO_HARDWARE=1 scripts/capture_uart.sh
```

Expected boot lines:
`I2C scan ...`, `POST fw=blink-i2c-oled ... i2c_oled=<0|1>`, then `LED on`/`LED off`.

## Caveats

- The IDE/clangd shows false `pico/stdlib.h not found` / `uint` errors because it
  lacks the SDK include path. The real cross-compiler build is the source of truth.
- If OpenOCD fails to claim the probe, a serial monitor or another OpenOCD may hold
  the USB device. Run with the `flash` tool or shell `disconnects_serial: true`.
- `scripts/build.sh`, `scripts/flash.sh`, `scripts/verify_all.sh` wrap these with
  evidence logging; real-hardware steps need `PICO_HARDWARE=1`.
- Do not self-enable `PICO_HARDWARE=1` as an agent. Ask or rely on an explicit
  user-provided command context.
