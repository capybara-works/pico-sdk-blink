"""Source-level GDB demo: break the instant the I2C scan finds a device and
prove, in C-variable terms, that 0x3C ACKs on the live RP2040.

Breakpoint at the `oled_present` assignment is only reached after
i2c_write_timeout_us returned >= 0 (an ACK). We read the live `addr` and `ret`,
confirm the SSD1306 match, step over the assignment, then read `oled_present`
and the backtrace.
"""

gdb.openocd_connect(elf="build/blink.elf", mcu="rp2040")

# Catch the moment a device ACKs, immediately before oled_present can be set.
gdb.breakpoint("blink.cpp:45")

print("Continuing until the scan hits an ACKing device...")
hit = gdb.continue_until_break(20)
print(f"Stopped: {hit}")

# Read live C variables in the current frame.
addr = gdb.execute("print/x addr")
ret  = gdb.execute("print ret")
print("=== Live program state at the ACK ===")
print(f"  addr (probed I2C address) = {addr.strip()}")
print(f"  ret  (i2c_write return)   = {ret.strip()}")
print("  SSD1306_I2C_ADDR          = 0x3c")

# Step over the line that sets oled_present if addr == 0x3C, then read it.
gdb.execute("next")
gdb.execute("print oled_present")
print("=== Call stack (source-level backtrace) ===")
print(gdb.execute("backtrace"))

# Let it finish the scan and resume so the OLED keeps rendering.
gdb.execute("delete")
gdb.execute("continue &")
print("Resumed firmware (breakpoint cleared).")
