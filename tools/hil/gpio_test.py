#!/usr/bin/env python3
"""
GPIO State Verification via OpenOCD
Reads GPIO state register (SIO GPIO_IN) via OpenOCD telnet interface
"""
import socket
import time
import re

def read_gpio_register(host="localhost", port=4444):
    """
    Read GPIO_IN register via OpenOCD TCL interface
    Register address: 0xd0000004 (RP2040 SIO GPIO_IN)
    
    Returns:
        int: GPIO register value (32-bit)
    """
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(5.0)
            s.connect((host, port))
            
            # Read welcome message
            welcome = s.recv(4096).decode('utf-8', errors='ignore')
            print(f"Connected to OpenOCD")
            
            # Halt target
            s.sendall(b"halt\n")
            time.sleep(0.2)
            halt_response = s.recv(4096).decode('utf-8', errors='ignore')
            
            # Read GPIO_IN register (0xd0000004)
            cmd = "mdw 0xd0000004\n"
            s.sendall(cmd.encode())
            time.sleep(0.1)
            response = s.recv(4096).decode('utf-8', errors='ignore')
            
            # Resume target
            s.sendall(b"resume\n")
            time.sleep(0.1)
            resume_response = s.recv(4096).decode('utf-8', errors='ignore')
            
            # Parse response
            # Expected format: "0xd0000004: 02000000"
            match = re.search(r'0xd0000004:\s*([0-9a-fA-F]+)', response)
            if match:
                value = int(match.group(1), 16)
                return value
            else:
                print(f"Failed to parse response: {response}")
                return None
                
    except Exception as e:
        print(f"Error: {e}")
        return None

def check_gpio_bit(gpio_num, gpio_value):
    """
    Check specific GPIO bit state
    
    Args:
        gpio_num: GPIO pin number (0-29)
        gpio_value: Full 32-bit GPIO register value
    
    Returns:
        int: 0 or 1
    """
    return (gpio_value >> gpio_num) & 1

def test_gp25_led():
    """Test GP25 LED state multiple times"""
    print("=" * 50)
    print("GP25 Internal LED State Verification")
    print("=" * 50)
    
    samples = []
    for i in range(10):
        gpio_value = read_gpio_register()
        if gpio_value is not None:
            gp25_state = check_gpio_bit(25, gpio_value)
            samples.append(gp25_state)
            print(f"Sample {i+1}: GP25 = {gp25_state} (GPIO_IN = 0x{gpio_value:08x})")
            time.sleep(0.3)  # Wait 300ms between samples
        else:
            print(f"Sample {i+1}: Failed to read")
    
    print("=" * 50)
    
    if not samples:
        print("❌ Test FAILED - Could not read GPIO state")
        return False
    
    # Check if we saw both states (0 and 1)
    has_high = 1 in samples
    has_low = 0 in samples
    
    print(f"\nResults:")
    print(f"  Samples collected: {len(samples)}")
    print(f"  High (1) detected: {has_high}")
    print(f"  Low (0) detected:  {has_low}")
    print(f"  State changes:     {len(set(samples)) > 1}")
    
    if has_high and has_low:
        print("\n✅ GP25 LED test PASSED - Both ON and OFF states detected")
        return True
    else:
        print("\n⚠️  GP25 LED test INCONCLUSIVE - Only one state detected")
        print("    (This may be due to timing - LED is blinking at 250ms intervals)")
        return samples  # Return samples for analysis

if __name__ == "__main__":
    import sys
    
    # Start OpenOCD in background if not running
    print("Note: This script requires OpenOCD to be running.")
    print("Start OpenOCD in another terminal with:")
    print("  openocd -f interface/cmsis-dap.cfg -c \"transport select swd; adapter speed 1000\" -f target/rp2040.cfg\n")
    
    result = test_gp25_led()
    
    if result == True:
        sys.exit(0)
    else:
        sys.exit(1)
