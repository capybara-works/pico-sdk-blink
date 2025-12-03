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
        port = "/dev/cu.usbmodem14201"  # Default for macOS
    
    lines = monitor_uart(port)
    
    if lines:
        # Check for expected patterns
        has_led_on = any("LED on" in line for line in lines)
        has_led_off = any("LED off" in line for line in lines)
        
        print(f"\nPattern Analysis:")
        print(f"  'LED on' found:  {has_led_on}")
        print(f"  'LED off' found: {has_led_off}")
        
        if has_led_on and has_led_off:
            print("\n✅ UART test PASSED - Expected patterns detected")
            sys.exit(0)
        else:
            print("\n❌ UART test FAILED - Expected patterns not found")
            sys.exit(1)
