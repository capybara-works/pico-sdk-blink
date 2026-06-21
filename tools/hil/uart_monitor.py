#!/usr/bin/env python3
"""
Simple UART monitor for Debug Probe
Reads serial output from the Pico via Debug Probe USB CDC
"""
import serial
import sys
import time

def monitor_uart(port, baudrate=115200, duration=5.0):
    """Monitor UART output for a specified duration"""
    try:
        with serial.Serial(port, baudrate, timeout=1.0) as ser:
            print(f"Connected to {port} @ {baudrate} baud")
            print(f"Monitoring for {duration} seconds...")
            print("-" * 40)
            
            start_time = time.time()
            lines_captured = []
            
            while time.time() - start_time < duration:
                if ser.in_waiting:
                    try:
                        line = ser.readline().decode('utf-8', errors='ignore').strip()
                        if line:
                            timestamp = time.time() - start_time
                            print(f"[{timestamp:6.3f}s] {line}")
                            lines_captured.append(line)
                    except Exception as e:
                        print(f"Error reading line: {e}")
            
            print("-" * 40)
            print(f"Captured {len(lines_captured)} lines")
            return lines_captured
            
    except serial.SerialException as e:
        print(f"Error opening serial port: {e}")
        return None

if __name__ == "__main__":
    if len(sys.argv) > 1:
        port = sys.argv[1]
    else:
        print("Usage: uart_monitor.py <serial_port> [duration_seconds]")
        sys.exit(2)

    duration = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0

    lines = monitor_uart(port, duration=duration)
    
    if lines:
        # Check for expected patterns. Keep pass/fail tied to the historical
        # LED contract, but report richer firmware health hints for operators.
        has_led_on = any("LED on" in line for line in lines)
        has_led_off = any("LED off" in line for line in lines)
        has_post_i2c_oled = any("POST " in line and "i2c_oled=1" in line for line in lines)
        has_oled_update = any("OLED updated" in line for line in lines)
        has_i2c_oled_addr = any("I2C device: 0x3C" in line for line in lines)
        bad_markers = [
            line for line in lines
            if any(marker in line for marker in (
                "i2c_oled=0",
                "I2C no devices",
                "lockup",
                "HardFault",
                "panic",
                "abort",
            ))
        ]
        
        print(f"\nPattern Analysis:")
        print(f"  'LED on' found:  {has_led_on}")
        print(f"  'LED off' found: {has_led_off}")
        print(f"  POST i2c_oled=1 found: {has_post_i2c_oled}")
        print(f"  OLED update found:      {has_oled_update}")
        print(f"  I2C 0x3C seen:          {has_i2c_oled_addr}")
        print(f"  health bad markers:     {len(bad_markers)}")
        
        if has_led_on and has_led_off:
            print("\n✅ UART test PASSED - Expected patterns detected")
            sys.exit(0)
        else:
            print("\n❌ UART test FAILED - Expected patterns not found")
            sys.exit(1)
    else:
        # No output at all (port error or silent target) must not pass.
        print("\n❌ UART test FAILED - No output captured")
        sys.exit(1)
