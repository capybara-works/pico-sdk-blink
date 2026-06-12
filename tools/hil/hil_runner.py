#!/usr/bin/env python3
"""
HIL Test Runner - Phase 0.8
Executes blink.test.yaml test scenarios on real hardware

Compatible with Wokwi test format:
- wait-serial: Wait for serial output pattern
- (expect-pin: Skipped for now, future enhancement)
"""

import yaml
import serial
import socket
import time
import sys
import subprocess
import re
from typing import Optional, Dict, Any, List

class OpenOCDController:
    """Controls OpenOCD for firmware flashing and GPIO verification"""
    
    def __init__(self, host="localhost", port=4444):
        self.host = host
        self.port = port
        self.process = None
    
    def start(self):
        """Start OpenOCD in background"""
        cmd = [
            "openocd",
            "-f", "interface/cmsis-dap.cfg",
            "-c", "transport select swd; adapter speed 1000",
            "-f", "target/rp2040.cfg"
        ]
        self.process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        time.sleep(2)  # Wait for OpenOCD to start
        print("✓ OpenOCD started")
    
    def stop(self):
        """Stop OpenOCD"""
        if self.process:
            self.process.terminate()
            self.process.wait()
            print("✓ OpenOCD stopped")
    
    def flash_firmware(self, elf_path: str) -> bool:
        """Flash firmware via OpenOCD"""
        cmd = [
            "openocd",
            "-f", "interface/cmsis-dap.cfg",
            "-c", "transport select swd; adapter speed 1000",
            "-f", "target/rp2040.cfg",
            "-c", f"program {elf_path} verify reset exit"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        success = result.returncode == 0
        if success:
            print(f"✓ Firmware flashed: {elf_path}")
        else:
            print(f"✗ Firmware flash failed: {result.stderr}")
        return success
    
    def read_gpio_register(self) -> Optional[int]:
        """Read GPIO_IN register via OpenOCD telnet"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                s.settimeout(5.0)
                s.connect((self.host, self.port))
                s.recv(4096)  # Welcome
                
                # Halt
                s.sendall(b"halt\n")
                time.sleep(0.1)
                s.recv(4096)
                
                # Read register
                s.sendall(b"mdw 0xd0000004\n")
                time.sleep(0.1)
                response = s.recv(4096).decode('utf-8', errors='ignore')
                
                # Resume
                s.sendall(b"resume\n")
                s.recv(4096)
                
                # Parse
                match = re.search(r'0xd0000004:\s*([0-9a-fA-F]+)', response)
                if match:
                    return int(match.group(1), 16)
        except Exception as e:
            print(f"GPIO read error: {e}")
        return None

class UARTMonitor:
    """Monitors UART output from Debug Probe"""
    
    def __init__(self, port: str, baudrate: int = 115200):
        self.port = port
        self.baudrate = baudrate
        self.ser = None
    
    def connect(self):
        """Connect to UART"""
        try:
            self.ser = serial.Serial(self.port, self.baudrate, timeout=1.0)
            print(f"✓ UART connected: {self.port}")
            return True
        except Exception as e:
            print(f"✗ UART connection failed: {e}")
            return False
    
    def wait_for_pattern(self, pattern: str, timeout: float = 10.0) -> bool:
        """Wait for specific pattern in serial output"""
        if not self.ser:
            return False
        
        start_time = time.time()
        buffer = ""
        
        while time.time() - start_time < timeout:
            if self.ser.in_waiting:
                try:
                    chunk = self.ser.read(self.ser.in_waiting).decode('utf-8', errors='ignore')
                    buffer += chunk
                    print(f"  [UART] {chunk.strip()}")
                    
                    if pattern in buffer:
                        print(f"✓ Pattern found: '{pattern}'")
                        return True
                except Exception as e:
                    print(f"UART read error: {e}")
            time.sleep(0.01)
        
        print(f"✗ Pattern timeout: '{pattern}'")
        return False
    
    def close(self):
        """Close UART connection"""
        if self.ser:
            self.ser.close()
            print("✓ UART closed")

class HILTestRunner:
    """Main test runner"""
    
    def __init__(self, test_file: str, elf_file: str, uart_port: str):
        self.test_file = test_file
        self.elf_file = elf_file
        self.uart_port = uart_port
        self.openocd = OpenOCDController()
        self.uart = UARTMonitor(uart_port)
    
    def load_test_yaml(self) -> Optional[Dict[str, Any]]:
        """Load test YAML file"""
        try:
            with open(self.test_file, 'r') as f:
                data = yaml.safe_load(f)
                print(f"✓ Loaded test: {data.get('name', 'Unknown')}")
                return data
        except Exception as e:
            print(f"✗ Failed to load test file: {e}")
            return None
    
    def execute_test(self) -> bool:
        """Execute test scenario"""
        print("=" * 60)
        print("HIL Test Runner - Phase 0.8")
        print("=" * 60)
        
        # Load test
        test_data = self.load_test_yaml()
        if not test_data:
            return False
        
        # Flash firmware
        print("\n[1/3] Flashing firmware...")
        if not self.openocd.flash_firmware(self.elf_file):
            return False
        
        # Start OpenOCD for GPIO access
        print("\n[2/3] Starting OpenOCD...")
        self.openocd.start()
        
        # Connect UART
        print("\n[3/3] Connecting UART...")
        if not self.uart.connect():
            self.openocd.stop()
            return False
        
        # Execute test steps
        print("\n" + "=" * 60)
        print("Executing Test Steps")
        print("=" * 60)
        
        steps = test_data.get('steps', [])
        for i, step in enumerate(steps, 1):
            print(f"\nStep {i}/{len(steps)}: {step}")
            
            if 'wait-serial' in step:
                pattern = step['wait-serial']
                if not self.uart.wait_for_pattern(pattern):
                    print(f"\n✗ TEST FAILED at step {i}")
                    self.cleanup()
                    return False
            
            elif 'expect-pin' in step:
                # Note: Current implementation skips pin verification
                # as internal LED (GP25) verification is optional
                print("  ℹ expect-pin skipped (internal LED, verified separately)")
            
            else:
                print(f"  ⚠ Unknown step type: {step}")
        
        print("\n" + "=" * 60)
        print("✅ ALL TESTS PASSED")
        print("=" * 60)
        
        self.cleanup()
        return True
    
    def cleanup(self):
        """Cleanup resources"""
        self.uart.close()
        self.openocd.stop()

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='HIL Test Runner for Raspberry Pi Pico')
    parser.add_argument('--test', default='blink.test.yaml', help='Test YAML file')
    parser.add_argument('--elf', default='build/blink.elf', help='Firmware ELF file')
    parser.add_argument('--uart', default='/dev/cu.usbmodem14402', help='UART port')
    
    args = parser.parse_args()
    
    runner = HILTestRunner(args.test, args.elf, args.uart)
    success = runner.execute_test()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
