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

- Device: `fx2lafw:conn=20.2` (confirm with `sigrok-cli --scan`).
- D0 = SCL (GP5), D1 = SDA (GP4), D2 = UART TX (GP0). GND common with the Pico.

## Capture I2C (timed to catch a scan)

The firmware scans at boot and every ~4 s, so capture >= 6 s.

```sh
sigrok-cli -d fx2lafw:conn=20.2 -C D0,D1 --config samplerate=2m --samples 12000000 -o /tmp/i2c.sr
sigrok-cli -i /tmp/i2c.sr -P i2c:scl=D0:sda=D1 -A i2c | head -40
```

Read it: `Start -> Address write: 3C -> ACK` = OLED present and healthy.
All `... -> NACK` (0 ACKs across 112 addresses) = nothing responding -> wiring/power.

## Decode UART

```sh
sigrok-cli -d fx2lafw:conn=20.2 -C D2 --config samplerate=2m --samples 6000000 -o /tmp/uart.sr
sigrok-cli -i /tmp/uart.sr -P uart:rx=D2:baudrate=115200 -A uart | head -40
```

## Continuity / edge check (diagnose loose taps)

Count edges per channel to find an open line. In I2C, SCL and SDA always toggle
together — a silent line is a physical break (usually D0/SCL): reseat it.

```sh
sigrok-cli -i /tmp/i2c.sr -O csv | \
  python3 -c "import sys;r=[l.split(',') for l in sys.stdin if l[:1] in '01'];\
d0=[x[0] for x in r];d1=[x[1] for x in r];\
e=lambda s:sum(a!=b for a,b in zip(s,s[1:]));\
print('D0(SCL) edges',e(d0),'D1(SDA) edges',e(d1))"
```

## Caveats

- A 1 s capture misses the periodic scan; always use >= 6 s.
- The analyzer's input threshold is lower than the RP2040 GPIO input — a floating
  line can read "high" on the analyzer but "low" at the MCU. Cross-check with
  `.embedder/hardware/i2c_probe.py` register reads when results disagree.
- For brand-name analyzers use the `debug-saleae` / `debug-digilent` skills instead.
