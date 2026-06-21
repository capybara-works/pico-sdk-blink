/**
 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include "pico/stdlib.h"
#include "hardware/i2c.h"
#include "hardware/adc.h"
#include "ssd1306_min.h"
#include <cmath>
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
    // Write probe: SSD1306 ACKs its address on WRITE but NACKs READ, so the
    // previous i2c_read probe could miss a healthy display. The harmless
    // single-byte probe returns the number of bytes written (>= 0) when ACKed.
    uint8_t probe = 0;
    int ret = i2c_write_timeout_us(i2c0, addr, &probe, 1, false, 5000);
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

// Power-On Self-Test: emit a single structured line so an AI/operator can read
// the board's physical state as text over the existing UART evidence path
// (no extra hardware). All integer milli-units to avoid float printf.
// Field names deliberately separate the measurement layers (raw vs ADC-pin
// voltage vs physical estimate) so the value can never be misread:
//   gp29_raw:     averaged ADC3 raw count (0-4095)
//   gp29_adc_mv:  voltage at the ADC pin = raw * 3300 / 4095
//   vsys_est_mv:  VSYS estimate = gp29_adc_mv * 3 (GP29 = internal VSYS/3 sense)
//   temp_mc:      internal temperature sensor (ADC4), milli-Celsius
//   vbus:         USB power present, GP24 sense
//   i2c_oled:     SSD1306 (0x3C) detected by the scan
// GP29's divider is ~67k (high impedance): the ADC sample-and-hold needs to
// settle, so we fix the mux, wait, discard, and average -- a single read
// under-reports (do NOT conclude a hardware/divider fault from one read).
static uint32_t adc_avg(int input, int discard, int samples) {
  adc_select_input(input);
  sleep_ms(2);
  for (int i = 0; i < discard; ++i) (void)adc_read();
  uint32_t acc = 0;
  for (int i = 0; i < samples; ++i) acc += adc_read();
  return acc / (uint32_t)samples;
}

// Sample the live board sensors (VSYS estimate, die temperature, VBUS).
// Emits a human-readable POST line plus Teleplot lines (prefixed '>') so the
// values can be streamed into a real-time plot without extra hardware.
void sample_and_report() {
  uint32_t gp29_raw = adc_avg(3, 16, 256);             // GP29 = VSYS/3 (high-Z)
  uint32_t gp29_adc_mv = gp29_raw * 3300u / 4095u;     // voltage at the ADC pin
  uint32_t vsys_est_mv = gp29_adc_mv * 3u;             // x3 divider -> VSYS
  uint32_t vtemp_mv = adc_avg(4, 16, 64) * 3300u / 4095u;
  int temp_mc = 27000 - (int)(vtemp_mv - 706) * 581;   // ~ -1/1.721 mV per deg
  int vbus = gpio_get(24);
  printf("POST fw=blink-i2c-oled gp29_raw=%u gp29_adc_mv=%u vsys_est_mv=%u temp_mc=%d vbus=%d i2c_oled=%d\n",
         (unsigned)gp29_raw, (unsigned)gp29_adc_mv, (unsigned)vsys_est_mv, temp_mc, vbus, oled_present ? 1 : 0);

  // Teleplot telemetry: convert milli-units to engineering units for the plot.
  uint32_t now_ms = to_ms_since_boot(get_absolute_time());
  printf(">vsys:%lu:%.3f\xC2\xA7V\r\n", (unsigned long)now_ms, vsys_est_mv / 1000.0);
  printf(">die_temp:%lu:%.2f\xC2\xA7\xC2\xB0\x43\r\n", (unsigned long)now_ms, temp_mc / 1000.0);
  printf(">vbus:%lu:%d\r\n", (unsigned long)now_ms, vbus);
}

void run_post() {
  adc_init();
  adc_gpio_init(29);
  adc_set_temp_sensor_enabled(true);
  gpio_init(24);
  gpio_set_dir(24, GPIO_IN);
  sample_and_report();
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
  printf("OLED updated fbcrc=0x%04X\n", ssd1306_buf_crc());
}

int main() {
  stdio_init_all();
  gpio_init(LED_PIN);
  gpio_set_dir(LED_PIN, GPIO_OUT);
  init_i2c();
  scan_i2c_bus();
  run_post();

  if (oled_present) {
    ssd1306_init(i2c0);
    oled_render(0);
  }

  uint blink_cycles = 0;
  double phase = 0.0;
  // Sweep the phasor in fine sub-steps so the XY plot draws a smooth, moving
  // circle/Lissajous. Each blink half-cycle (250 ms) is split into 10 x 25 ms
  // steps. wave_x=cos, wave_y=sin -> a rotating unit circle in XY mode.
  auto emit_wave = [&]() {
    phase += 0.20;                       // ~0.2 rad per 25 ms step
    if (phase > 6.28318530718) phase -= 6.28318530718;
    uint32_t now = to_ms_since_boot(get_absolute_time());
    printf(">wave_x:%lu:%.4f\r\n", (unsigned long)now, cos(phase));
    printf(">wave_y:%lu:%.4f\r\n", (unsigned long)now, sin(phase * 2.0)); // 2:1 Lissajous
  };
  auto blink_half = [&](int level) {
    gpio_put(LED_PIN, level);
    printf(level ? "LED on\n" : "LED off\n");
    printf(">led:%lu:%d\r\n", (unsigned long)to_ms_since_boot(get_absolute_time()), level);
    for (int i = 0; i < 10; ++i) { emit_wave(); sleep_ms(25); }
  };

  while (true) {
    blink_half(1);
    blink_half(0);
    ++blink_cycles;
    if (oled_present) {
      oled_render(blink_cycles);
    }
    // Re-sample VSYS / temperature / VBUS every cycle so the plot stays live.
    sample_and_report();
    if (blink_cycles % 8 == 0) {
      scan_i2c_bus();
    }
  }
  return 0;
}
