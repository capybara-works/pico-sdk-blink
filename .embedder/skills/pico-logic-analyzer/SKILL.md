---
name: pico-logic-analyzer
description: >-
  Capture and protocol-decode I2C/UART on the pico-sdk-blink rig with the cheap
  fx2lafw logic analyzer via sigrok-cli. Use when asked to probe the bus, decode
  I2C/UART, check SDA/SCL edges, or verify wiring continuity on GP4/GP5/GP0.
---

> **Provenance: AI-generated.** This is an unofficial, project-local skill
> authored by the Embedder AI agent during a debug session (2026-06-18), not an
> official Embedder skill. Content is distilled from verified observations on
> this rig, but review before relying on it. Edit freely.

# fx2lafw logic-analyzer capture & decode (sigrok)

## Device & channel map

- Device: `fx2lafw`; `conn` is local state and may change after reconnect.
  Confirm with `sigrok-cli --driver fx2lafw --scan` and store it in
  `config/hardware.local.yaml` rather than hard-coding it.
- D0 = SCL (GP5), D1 = SDA (GP4), D2 = UART TX (GP0). GND common with the Pico.

## Capture I2C (timed to catch a scan)

The firmware scans at boot and every ~4 s, so capture >= 6 s. Prefer the gated
repository wrapper:

```sh
PICO_LOGIC_I2C=1 scripts/capture_logic_i2c.sh 6000
```

Read it: `Start -> Address write: 3C -> ACK` = OLED present and healthy.
All `... -> NACK` (0 ACKs across 112 addresses) = nothing responding -> wiring/power.

## Decode UART

```sh
PICO_LOGIC_UART=1 scripts/capture_logic_uart.sh 6000
```

## Continuity / edge check (diagnose loose taps)

Count edges per channel to find an open line. In I2C, SCL and SDA always toggle
together — a silent line is a physical break (usually D0/SCL): reseat it.

```sh
PICO_LOGIC_I2C=1 scripts/probe_logic_activity.sh 6000
```

## Caveats

- A 1 s capture misses the periodic scan; always use >= 6 s.
- The analyzer's input threshold is lower than the RP2040 GPIO input — a floating
  line can read "high" on the analyzer but "low" at the MCU. Cross-check with
  `.embedder/hardware/i2c_probe.py` register reads when results disagree.
- For brand-name analyzers use the `debug-saleae` / `debug-digilent` skills instead.
