set pagination off
target extended-remote localhost:3333
monitor reset halt
break blink.cpp:42
echo \n===> running until an I2C device ACKs...\n
monitor reset run
continue
echo \n===== LIVE PROGRAM STATE AT THE ACK =====\n
print/x addr
print ret
echo (addr=0x3C and ret>=0 means the SSD1306 ACKed)\n
echo \n===== SOURCE LISTING AROUND BREAK =====\n
list blink.cpp:40,46
echo \n===== CALL STACK (source-level backtrace) =====\n
backtrace
echo \n===== STEP OVER: run the oled_present assignment =====\n
next
next
print oled_present
echo \n===== I2C0 hardware abort source (0 = clean ACK) =====\n
x/1xw 0x40044080
delete
detach
quit
