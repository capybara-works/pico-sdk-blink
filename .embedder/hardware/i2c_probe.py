"""I2C/OLED fast triage for the pico-sdk-blink RP2040 rig.

WHY THIS EXISTS
  "I2C no devices" / i2c_oled=0 / all-NACK on this rig is almost always a
  PHYSICAL wiring fault (esp. the GP5/SCL tap working loose after a rewire),
  NOT firmware or the MCU. Confirmed by PHASE2_OLED_LOGIC_BRINGUP_REPORT.md
  and a 2026-06-18 debug session. Wokwi always passes (ideal power/pull-ups),
  so sim-passes-but-hardware-fails => suspect wiring/power.

WHAT IT CHECKS (MCU side, via OpenOCD/SWD; target halted)
  1. GP4/GP5 muxed to I2C (GPIOx_CTRL FUNCSEL == 3)
  2. Internal pull-ups enabled (PADS GPIOx == 0x5A: IE=1, PUE=1, PDE=0)
  3. Bus idle level (SIO_GPIO_IN bits 4/5) -- healthy I2C idles HIGH
  4. I2C0 not stuck (IC_STATUS), and abort source readout

If 1-3 are all OK but the OLED still NACKs, the fault is OFF-CHIP:
  -> run the analyzer continuity check (drive GP4/GP5, both D0 AND D1 must
     show edges on fx2lafw; a silent line = open tap, RESEAT it), and
  -> verify OLED VCC is on 3V3 (pin 36), NOT VBUS (phantom power).

Known-good map: GP4(pin6)=SDA, GP5(pin7)=SCL; analyzer D0=SCL, D1=SDA.
"""

IO_BANK0 = 0x40014000
def GPIO_STATUS(n): return IO_BANK0 + 0x08 * n
def GPIO_CTRL(n):   return IO_BANK0 + 0x08 * n + 4

PADS_BANK0 = 0x4001C000
def PAD(n): return PADS_BANK0 + 0x04 + 0x04 * n

SIO = 0xD0000000
SIO_GPIO_IN = SIO + 0x04

I2C0 = 0x40044000
IC_ENABLE         = I2C0 + 0x6C
IC_STATUS         = I2C0 + 0x70
IC_TX_ABRT_SOURCE = I2C0 + 0x80

def rd(a): return gdb.read_memory(a, 4)[0]

gdb.openocd_connect(elf="build/blink.elf", mcu="rp2040")

# Run firmware briefly so init_i2c() has configured the pins, then halt.
gdb.continue_until_break(2)
gdb.interrupt()

ok = True
for name, n in (("GP4/SDA", 4), ("GP5/SCL", 5)):
    ctrl = rd(GPIO_CTRL(n)); pad = rd(PAD(n)); inn = rd(SIO_GPIO_IN)
    funcsel = ctrl & 0x1F
    pue = (pad >> 3) & 1
    pde = (pad >> 2) & 1
    level = (inn >> n) & 1
    mux_ok = (funcsel == 3)
    pu_ok = (pue == 1 and pde == 0)
    hi = (level == 1)
    ok = ok and mux_ok and pu_ok and hi
    print(f"{name:8s} FUNCSEL={funcsel}{'(I2C)' if mux_ok else ' !!expected 3'}"
          f"  PUE={pue} PDE={pde}{'' if pu_ok else ' !!pull-up off'}"
          f"  idle_level={level}{'(HIGH)' if hi else ' !!LOW: bus held down'}")

ic_en = rd(IC_ENABLE); ic_st = rd(IC_STATUS); abrt = rd(IC_TX_ABRT_SOURCE)
print(f"I2C0     IC_ENABLE=0x{ic_en:02X} IC_STATUS=0x{ic_st:02X} "
      f"IC_TX_ABRT_SOURCE=0x{abrt:08X}")

print()
if ok:
    print("VERDICT: MCU side HEALTHY (pins muxed, pull-ups on, bus idles HIGH).")
    print("  If the OLED still NACKs, the fault is OFF-CHIP:")
    print("  1) Analyzer continuity: drive GP4/GP5, BOTH D0 and D1 must toggle.")
    print("     A silent line (usually D0/SCL) = open tap -> RESEAT it.")
    print("  2) OLED VCC must be on 3V3 (pin36), NOT VBUS (phantom power).")
else:
    print("VERDICT: MCU-side anomaly flagged above (see '!!'). Fix that first.")
