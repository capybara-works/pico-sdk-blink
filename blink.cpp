/**
 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "pico/stdlib.h"
#include "hardware/i2c.h"
#include "ssd1306_min.h"
#include <cstdint>
#include <stdio.h>

const uint LED_PIN = PICO_DEFAULT_LED_PIN;
const uint I2C_SDA_PIN = 4;
const uint I2C_SCL_PIN = 5;
const uint32_t I2C_BAUD_RATE = 100 * 1000;

void init_i2c() {
  i2c_init(i2c0, I2C_BAUD_RATE);
  gpio_set_function(I2C_SDA_PIN, GPIO_FUNC_I2C);
  gpio_set_function(I2C_SCL_PIN, GPIO_FUNC_I2C);
  gpio_pull_up(I2C_SDA_PIN);
  gpio_pull_up(I2C_SCL_PIN);
}

bool oled_present = false;

void scan_i2c_bus() {
  printf("I2C scan start\n");
  bool found = false;

  for (uint8_t addr = 0x08; addr <= 0x77; ++addr) {
    uint8_t probe = 0;
    int ret = i2c_read_timeout_us(i2c0, addr, &probe, 1, false, 5000);
    if (ret >= 0) {
      printf("I2C device: 0x%02X\n", addr);
      found = true;
      if (addr == SSD1306_I2C_ADDR) oled_present = true;
    }
  }

  if (!found) {
    printf("I2C no devices\n");
  }
  printf("I2C scan done\n");
}

// Render the static labels plus a live blink counter on the OLED.
void oled_render(uint blink_cycles) {
  char count_line[16];
  snprintf(count_line, sizeof(count_line), "BLINK %u", blink_cycles);

  ssd1306_clear();
  ssd1306_draw_string(0, 0, "RP2040 PICO LAB");
  ssd1306_draw_string(0, 2, "I2C OLED OK");
  ssd1306_draw_string(0, 4, "ADDR 3C FOUND");
  ssd1306_draw_string(0, 6, count_line);
  ssd1306_show(i2c0);
  printf("OLED updated\n");
}

int main() {
  stdio_init_all();
  gpio_init(LED_PIN);
  gpio_set_dir(LED_PIN, GPIO_OUT);
  init_i2c();
  scan_i2c_bus();

  if (oled_present) {
    ssd1306_init(i2c0);
    oled_render(0);
  }

  uint blink_cycles = 0;
  while (true) {
    gpio_put(LED_PIN, 1);
    printf("LED on\n");
    sleep_ms(250);
    gpio_put(LED_PIN, 0);
    printf("LED off\n");
    sleep_ms(250);
    ++blink_cycles;
    if (oled_present) {
      oled_render(blink_cycles);
    }
    if (blink_cycles % 8 == 0) {
      scan_i2c_bus();
    }
  }
  return 0;
}
