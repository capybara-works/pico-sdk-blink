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
#include <cstdint>
#include <cstring>

#define SSD1306_I2C_ADDR 0x3C
#define SSD1306_WIDTH 128
#define SSD1306_HEIGHT 64
#define SSD1306_PAGES (SSD1306_HEIGHT / 8)

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

static void ssd1306_cmd(i2c_inst_t *i2c, uint8_t cmd) {
  uint8_t pkt[2] = {0x00, cmd}; // 0x00 = command stream
  i2c_write_blocking(i2c, SSD1306_I2C_ADDR, pkt, 2, false);
}

static void ssd1306_init(i2c_inst_t *i2c) {
  static const uint8_t seq[] = {
      0xAE,             // display off
      0xD5, 0x80,       // clock divide ratio
      0xA8, 0x3F,       // multiplex ratio = 63 (64 rows)
      0xD3, 0x00,       // display offset
      0x40,             // start line 0
      0x8D, 0x14,       // charge pump on
      0x20, 0x00,       // memory mode: horizontal
      0xA1,             // segment remap
      0xC8,             // COM scan direction remapped
      0xDA, 0x12,       // COM pins config
      0x81, 0xCF,       // contrast
      0xD9, 0xF1,       // pre-charge
      0xDB, 0x40,       // VCOM detect
      0xA4,             // resume to RAM content
      0xA6,             // normal (non-inverted)
      0xAF,             // display on
  };
  for (uint8_t b : seq) ssd1306_cmd(i2c, b);
  memset(ssd1306_buf, 0, sizeof(ssd1306_buf));
}

static void ssd1306_clear() { memset(ssd1306_buf, 0, sizeof(ssd1306_buf)); }

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

// Push the framebuffer to the panel.
static void ssd1306_show(i2c_inst_t *i2c) {
  ssd1306_cmd(i2c, 0x21); // column address
  ssd1306_cmd(i2c, 0x00);
  ssd1306_cmd(i2c, SSD1306_WIDTH - 1);
  ssd1306_cmd(i2c, 0x22); // page address
  ssd1306_cmd(i2c, 0x00);
  ssd1306_cmd(i2c, SSD1306_PAGES - 1);

  // Data must be sent with a 0x40 control byte prefix.
  uint8_t pkt[1 + SSD1306_WIDTH];
  for (int page = 0; page < SSD1306_PAGES; ++page) {
    pkt[0] = 0x40; // data stream
    memcpy(&pkt[1], &ssd1306_buf[page * SSD1306_WIDTH], SSD1306_WIDTH);
    i2c_write_blocking(i2c, SSD1306_I2C_ADDR, pkt, sizeof(pkt), false);
  }
}

#endif // SSD1306_MIN_H
