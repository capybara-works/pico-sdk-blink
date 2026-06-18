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

Known-good toolchain and commands for this project. Use these verbatim.

## Environment

- `PICO_SDK_PATH=/Users/mitokouki/pico-sdk` (required; build fails to configure without it).
- ARM GCC at `/Applications/ArmGNUToolchain/14.2.rel1/...`, CMake, OpenOCD all on PATH.
- Probe: Raspberry Pi Debug Probe (CMSIS-DAP) on `/dev/cu.usbmodem14202`.
- Build dir: `build/`. Targets: `build/blink.elf`, `build/blink.uf2`, `build/blink.bin`.

## Configure (first time / after CMakeLists change)

```sh
PICO_SDK_PATH=/Users/mitokouki/pico-sdk cmake -S . -B build
```

## Build

```sh
PICO_SDK_PATH=/Users/mitokouki/pico-sdk cmake --build build -j4
```

Expected: `[100%] Built target blink`. Check size with `arm-none-eabi-size build/blink.elf`
(baseline ~30 KB text / ~2.5 KB bss).

## Flash (OpenOCD + SWD) and capture boot serial

Prefer the `flash` tool so boot logs are captured from the first byte. Command:

```sh
openocd -f interface/cmsis-dap.cfg \
  -c "transport select swd; adapter speed 1000" \
  -f target/rp2040.cfg \
  -c "program build/blink.elf verify reset exit"
```

Monitor port `/dev/cu.usbmodem14202` @ 115200. Expected boot lines:
`I2C scan ...`, `POST fw=blink-i2c-oled ... i2c_oled=<0|1>`, then `LED on`/`LED off`.

## Caveats

- The IDE/clangd shows false `pico/stdlib.h not found` / `uint` errors because it
  lacks the SDK include path. The real cross-compiler build is the source of truth.
- If OpenOCD fails to claim the probe, a serial monitor or another OpenOCD may hold
  the USB device. Run with the `flash` tool or shell `disconnects_serial: true`.
- `scripts/build.sh`, `scripts/flash.sh`, `scripts/verify_all.sh` wrap these with
  evidence logging; real-hardware steps need `PICO_HARDWARE=1`.
