/**
 * Minimal SSD1306 (128x64, I2C) driver for the Embedded AI Agent Lab.
 *
 * Scope: just enough to prove the OLED renders in Wokwi / on hardware.
 * Supports a 5x7 font covering space, digits 0-9 and uppercase A-Z.
 * Unsupported characters are drawn as blank.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */
#ifndef SSD1306_MIN_H
#define SSD1306_MIN_H

#include "hardware/i2c.h"
#include "pico/stdlib.h"
#include <cstdint>
#include <cstring>
#include <stdio.h>

#define SSD1306_I2C_ADDR 0x3C
#define SSD1306_WIDTH 128
#define SSD1306_HEIGHT 64
#define SSD1306_PAGES (SSD1306_HEIGHT / 8)
// A 129-byte page write takes about 11.6 ms at 100 kHz, and about 23.2 ms at
// 50 kHz. Keep the timeout above that so page transfers are not self-inflicted
// false failures.
#define SSD1306_I2C_TIMEOUT_US 50000

#ifndef SSD1306_DIAG_VERBOSE
#define SSD1306_DIAG_VERBOSE 1
#endif

enum Ssd1306TestMode {
  OLED_TEST_CLEAR,
  OLED_TEST_ALL_ON,
  OLED_TEST_NORMAL,
  OLED_TEST_PATTERN,
};

// 5x7 glyphs, column-major, bit0 = top row. Index: space, '0'-'9', 'A'-'Z'.
static const uint8_t SSD1306_FONT[][5] = {
    {0x00, 0x00, 0x00, 0x00, 0x00}, // ' '
    {0x3E, 0x51, 0x49, 0x45, 0x3E}, // 0
    {0x00, 0x42, 0x7F, 0x40, 0x00}, // 1
    {0x42, 0x61, 0x51, 0x49, 0x46}, // 2
    {0x21, 0x41, 0x45, 0x4B, 0x31}, // 3
    {0x18, 0x14, 0x12, 0x7F, 0x10}, // 4
    {0x27, 0x45, 0x45, 0x45, 0x39}, // 5
    {0x3C, 0x4A, 0x49, 0x49, 0x30}, // 6
    {0x01, 0x71, 0x09, 0x05, 0x03}, // 7
    {0x36, 0x49, 0x49, 0x49, 0x36}, // 8
    {0x06, 0x49, 0x49, 0x29, 0x1E}, // 9
    {0x7E, 0x11, 0x11, 0x11, 0x7E}, // A
    {0x7F, 0x49, 0x49, 0x49, 0x36}, // B
    {0x3E, 0x41, 0x41, 0x41, 0x22}, // C
    {0x7F, 0x41, 0x41, 0x22, 0x1C}, // D
    {0x7F, 0x49, 0x49, 0x49, 0x41}, // E
    {0x7F, 0x09, 0x09, 0x09, 0x01}, // F
    {0x3E, 0x41, 0x49, 0x49, 0x7A}, // G
    {0x7F, 0x08, 0x08, 0x08, 0x7F}, // H
    {0x00, 0x41, 0x7F, 0x41, 0x00}, // I
    {0x20, 0x40, 0x41, 0x3F, 0x01}, // J
    {0x7F, 0x08, 0x14, 0x22, 0x41}, // K
    {0x7F, 0x40, 0x40, 0x40, 0x40}, // L
    {0x7F, 0x02, 0x0C, 0x02, 0x7F}, // M
    {0x7F, 0x04, 0x08, 0x10, 0x7F}, // N
    {0x3E, 0x41, 0x41, 0x41, 0x3E}, // O
    {0x7F, 0x09, 0x09, 0x09, 0x06}, // P
    {0x3E, 0x41, 0x51, 0x21, 0x5E}, // Q
    {0x7F, 0x09, 0x19, 0x29, 0x46}, // R
    {0x46, 0x49, 0x49, 0x49, 0x31}, // S
    {0x01, 0x01, 0x7F, 0x01, 0x01}, // T
    {0x3F, 0x40, 0x40, 0x40, 0x3F}, // U
    {0x1F, 0x20, 0x40, 0x20, 0x1F}, // V
    {0x7F, 0x20, 0x18, 0x20, 0x7F}, // W
    {0x63, 0x14, 0x08, 0x14, 0x63}, // X
    {0x07, 0x08, 0x70, 0x08, 0x07}, // Y
    {0x61, 0x51, 0x49, 0x45, 0x43}, // Z
};

static uint8_t ssd1306_buf[SSD1306_WIDTH * SSD1306_PAGES];

static int ssd1306_font_index(char c) {
  if (c == ' ') return 0;
  if (c >= '0' && c <= '9') return 1 + (c - '0');
  if (c >= 'A' && c <= 'Z') return 11 + (c - 'A');
  return 0; // unsupported -> blank
}

static void ssd1306_clear() { memset(ssd1306_buf, 0, sizeof(ssd1306_buf)); }

// CRC-16 of the framebuffer: a cheap "what did I write" fingerprint that the
// POST/render path reports over UART. Proves the write path/content (not that
// pixels actually lit -- pair with INA260 current and/or a camera for that).
static uint16_t ssd1306_buf_crc() {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < sizeof(ssd1306_buf); ++i) {
    crc ^= ssd1306_buf[i];
    for (int b = 0; b < 8; ++b)
      crc = (crc & 1) ? (uint16_t)((crc >> 1) ^ 0xA001) : (uint16_t)(crc >> 1);
  }
  return crc;
}

static const char *ssd1306_test_mode_name(Ssd1306TestMode mode) {
  switch (mode) {
  case OLED_TEST_CLEAR: return "CLEAR";
  case OLED_TEST_ALL_ON: return "ALL_ON";
  case OLED_TEST_NORMAL: return "NORMAL";
  case OLED_TEST_PATTERN: return "PATTERN";
  }
  return "UNKNOWN";
}

static int ssd1306_write_once(i2c_inst_t *i2c, const uint8_t *pkt,
                              int expected) {
  return i2c_write_timeout_us(i2c, SSD1306_I2C_ADDR, pkt, expected, false,
                              SSD1306_I2C_TIMEOUT_US);
}

static int ssd1306_write_checked(i2c_inst_t *i2c, const char *phase,
                                 const uint8_t *pkt, int expected) {
  int ret = ssd1306_write_once(i2c, pkt, expected);
  if (ret != expected) {
    int first_ret = ret;
    sleep_ms(2);
    ret = ssd1306_write_once(i2c, pkt, expected);
    printf("OLED_I2C_RETRY phase=%s expected=%d first_ret=%d ret=%d ok=%d\n",
           phase, expected, first_ret, ret, ret == expected ? 1 : 0);
  }
  if (ret != expected) {
    printf("OLED_I2C_ERROR phase=%s expected=%d ret=%d\n", phase, expected,
           ret);
  }
  return ret;
}

static bool ssd1306_cmd_phase(i2c_inst_t *i2c, const char *phase, uint8_t cmd) {
  uint8_t pkt[2] = {0x00, cmd}; // 0x00 = command stream
  int ret = ssd1306_write_checked(i2c, phase, pkt, (int)sizeof(pkt));
  bool ok = (ret == (int)sizeof(pkt));
  if (SSD1306_DIAG_VERBOSE || !ok) {
    printf("OLED_CMD phase=%s cmd=0x%02X ret=%d ok=%d\n",
           phase, cmd, ret, ok ? 1 : 0);
  }
  return ok;
}

static bool ssd1306_set_page_origin(i2c_inst_t *i2c, const char *phase,
                                    int page) {
  bool ok = true;
  ok &= ssd1306_cmd_phase(i2c, phase, (uint8_t)(0xB0 + page));
  ok &= ssd1306_cmd_phase(i2c, phase, 0x00); // lower column
  ok &= ssd1306_cmd_phase(i2c, phase, 0x10); // upper column
  return ok;
}

static bool ssd1306_cmd2_phase(i2c_inst_t *i2c, const char *phase,
                               uint8_t cmd, uint8_t arg) {
  uint8_t pkt[3] = {0x00, cmd, arg}; // command stream with one argument
  int ret = ssd1306_write_checked(i2c, phase, pkt, (int)sizeof(pkt));
  bool ok = (ret == (int)sizeof(pkt));
  if (SSD1306_DIAG_VERBOSE || !ok) {
    printf("OLED_CMD2 phase=%s cmd=0x%02X arg=0x%02X ret=%d ok=%d\n",
           phase, cmd, arg, ret, ok ? 1 : 0);
  }
  return ok;
}

struct Ssd1306InitStep {
  uint8_t cmd;
  uint8_t arg;
  bool has_arg;
};

static bool ssd1306_init(i2c_inst_t *i2c) {
  static const Ssd1306InitStep seq[] = {
      {0xAE, 0x00, false}, // display off
      {0xD5, 0x80, true},  // clock divide ratio
      {0xA8, 0x3F, true},  // multiplex ratio = 63 (64 rows)
      {0xD3, 0x00, true},  // display offset
      {0x40, 0x00, false}, // start line 0
      {0x8D, 0x14, true},  // charge pump on
      {0x20, 0x02, true},  // memory mode: page addressing
      {0xA1, 0x00, false}, // segment remap
      {0xC8, 0x00, false}, // COM scan direction remapped
      {0xDA, 0x12, true},  // COM pins config
      {0x81, 0xCF, true},  // contrast
      {0xD9, 0xF1, true},  // pre-charge
      {0xDB, 0x40, true},  // VCOM detect
      {0xA4, 0x00, false}, // resume to RAM content
      {0xA6, 0x00, false}, // normal (non-inverted)
      {0xAF, 0x00, false}, // display on
  };

  printf("OLED_INIT start addr=0x%02X\n", SSD1306_I2C_ADDR);
  bool ok = true;
  for (const auto &step : seq) {
    ok &= step.has_arg
              ? ssd1306_cmd2_phase(i2c, "init", step.cmd, step.arg)
              : ssd1306_cmd_phase(i2c, "init", step.cmd);
  }
  // Real SSD1306 panels need the charge pump to settle after display-on before
  // RAM writes are visible; without this delay the panel stays blank on
  // hardware (Wokwi does not require it).
  sleep_ms(100);
  ssd1306_clear();
  printf("OLED_INIT result=%s\n", ok ? "ok" : "fail");
  return ok;
}

// Draw a string at column x (pixels) on the given text row (page, 0..7).
static void ssd1306_draw_string(int x, int page, const char *s) {
  if (page < 0 || page >= SSD1306_PAGES) return;
  int col = x;
  for (; *s && col + 5 <= SSD1306_WIDTH; ++s) {
    const uint8_t *g = SSD1306_FONT[ssd1306_font_index(*s)];
    for (int i = 0; i < 5; ++i) ssd1306_buf[page * SSD1306_WIDTH + col + i] = g[i];
    col += 5;
    if (col < SSD1306_WIDTH) ssd1306_buf[page * SSD1306_WIDTH + col] = 0x00; // 1px gap
    col += 1;
  }
}

static void ssd1306_fill(uint8_t value) {
  memset(ssd1306_buf, value, sizeof(ssd1306_buf));
}

static void ssd1306_fill_pattern() {
  for (int page = 0; page < SSD1306_PAGES; ++page) {
    for (int col = 0; col < SSD1306_WIDTH; ++col) {
      bool even = (((col / 8) + page) & 1) == 0;
      ssd1306_buf[page * SSD1306_WIDTH + col] = even ? 0xAA : 0x55;
    }
  }
}

static bool ssd1306_show(i2c_inst_t *i2c);

static bool ssd1306_test(i2c_inst_t *i2c, Ssd1306TestMode mode) {
  printf("OLED_TEST mode=%s start\n", ssd1306_test_mode_name(mode));

  bool ok = true;
  switch (mode) {
  case OLED_TEST_CLEAR:
    ok &= ssd1306_cmd_phase(i2c, "test_clear", 0xA4);
    ok &= ssd1306_cmd_phase(i2c, "test_clear", 0xA6);
    ssd1306_fill(0x00);
    ok &= ssd1306_show(i2c);
    break;
  case OLED_TEST_ALL_ON:
    ok &= ssd1306_cmd_phase(i2c, "test_all_on", 0xA5);
    break;
  case OLED_TEST_NORMAL:
    ok &= ssd1306_cmd_phase(i2c, "test_normal", 0xA4);
    ok &= ssd1306_cmd_phase(i2c, "test_normal", 0xA6);
    ok &= ssd1306_show(i2c);
    break;
  case OLED_TEST_PATTERN:
    ok &= ssd1306_cmd_phase(i2c, "test_pattern", 0xA4);
    ok &= ssd1306_cmd_phase(i2c, "test_pattern", 0xA6);
    ssd1306_fill_pattern();
    ok &= ssd1306_show(i2c);
    break;
  }

  printf("OLED_TEST mode=%s result=%s fbcrc=0x%04X\n",
         ssd1306_test_mode_name(mode), ok ? "ok" : "fail",
         ssd1306_buf_crc());
  return ok;
}

static bool ssd1306_recover(i2c_inst_t *i2c) {
  printf("OLED_RECOVER start\n");
  bool cmds_ok = true;
  cmds_ok &= ssd1306_cmd_phase(i2c, "recover", 0xAE);      // display off
  cmds_ok &= ssd1306_cmd_phase(i2c, "recover", 0xA4);      // RAM content
  cmds_ok &= ssd1306_cmd_phase(i2c, "recover", 0xA6);      // normal display
  cmds_ok &= ssd1306_cmd2_phase(i2c, "recover", 0x8D, 0x14); // charge pump
  cmds_ok &= ssd1306_cmd_phase(i2c, "recover", 0xAF);      // display on
  sleep_ms(100);

  bool clear_ok = ssd1306_test(i2c, OLED_TEST_CLEAR);
  bool pattern_ok = ssd1306_test(i2c, OLED_TEST_PATTERN);
  bool ok = cmds_ok && clear_ok && pattern_ok;
  printf("OLED_RECOVER result=%s cmds_ok=%d clear_ok=%d pattern_ok=%d fbcrc=0x%04X\n",
         ok ? "ok" : "fail", cmds_ok ? 1 : 0, clear_ok ? 1 : 0,
         pattern_ok ? 1 : 0, ssd1306_buf_crc());
  return ok;
}

// Push the framebuffer to the panel.
static bool ssd1306_show(i2c_inst_t *i2c) {
  // Data must be sent with a 0x40 control byte prefix. Set the page/column
  // before each row so clone panels do not depend on address-pointer state
  // surviving across separate I2C transactions.
  uint8_t pkt[1 + SSD1306_WIDTH];
  int pages_ok = 0;
  int pages_fail = 0;
  for (int page = 0; page < SSD1306_PAGES; ++page) {
    bool page_ok = ssd1306_set_page_origin(i2c, "show", page);

    int ret = -999;
    pkt[0] = 0x40; // data stream
    memcpy(&pkt[1], &ssd1306_buf[page * SSD1306_WIDTH], SSD1306_WIDTH);
    if (page_ok) {
      ret = ssd1306_write_once(i2c, pkt, (int)sizeof(pkt));
      if (ret != (int)sizeof(pkt)) {
        int first_ret = ret;
        sleep_ms(2);
        bool reset_ok = ssd1306_set_page_origin(i2c, "show_retry", page);
        if (reset_ok) {
          ret = ssd1306_write_once(i2c, pkt, (int)sizeof(pkt));
        }
        printf("OLED_I2C_RETRY phase=show page=%d expected=%d first_ret=%d ret=%d reset_ok=%d ok=%d\n",
               page, (int)sizeof(pkt), first_ret, ret, reset_ok ? 1 : 0,
               ret == (int)sizeof(pkt) ? 1 : 0);
      }
      if (ret != (int)sizeof(pkt)) {
        printf("OLED_I2C_ERROR phase=show page=%d expected=%d ret=%d\n",
               page, (int)sizeof(pkt), ret);
      }
      page_ok = (ret == (int)sizeof(pkt));
    }
    if (SSD1306_DIAG_VERBOSE || !page_ok) {
      printf("OLED_PAGE page=%d ret=%d ok=%d\n",
             page, ret, page_ok ? 1 : 0);
    }
    if (page_ok) {
      ++pages_ok;
    } else {
      ++pages_fail;
    }
  }
  bool ok = (pages_fail == 0);
  printf("OLED_SHOW result=%s pages_ok=%d pages_fail=%d fbcrc=0x%04X\n",
         ok ? "ok" : "fail", pages_ok, pages_fail, ssd1306_buf_crc());
  return ok;
}

#endif // SSD1306_MIN_H
