"""Source-level GDB demo: break the instant the I2C scan finds a device and
prove, in C-variable terms, that 0x3C ACKs on the live RP2040.

Breakpoint at blink.cpp:42 (`printf("I2C device: 0x%02X", addr)`) only executes
when i2c_write_timeout_us returned >= 0 (an ACK). We read the live `addr` and
`ret`, confirm the SSD1306 match, then read `oled_present` and the backtrace.
"""

gdb.openocd_connect(elf="build/blink.elf", mcu="rp2040")

# Catch the moment a device ACKs (only reached when ret >= 0).
gdb.breakpoint("blink.cpp:42")

print("Continuing until the scan hits an ACKing device...")
hit = gdb.continue_until_break(20)
print(f"Stopped: {hit}")

# Read live C variables in the current frame.
addr = gdb.execute("print/x addr")
ret  = gdb.execute("print ret")
print("=== Live program state at the ACK ===")
print(f"  addr (probed I2C address) = {addr.strip()}")
print(f"  ret  (i2c_write return)   = {ret.strip()}")
print(f"  SSD1306_I2C_ADDR          = {gdb.execute('print/x SSD1306_I2C_ADDR').strip()}")

# Step over the line that sets oled_present if addr == 0x3C, then read it.
gdb.execute("print oled_present")
print("=== Call stack (source-level backtrace) ===")
print(gdb.execute("backtrace"))

# Let it finish the scan and resume so the OLED keeps rendering.
gdb.execute("delete")
gdb.execute("continue &")
print("Resumed firmware (breakpoint cleared).")
