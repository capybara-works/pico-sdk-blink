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
const uint32_t I2C_RECOVERY_BAUD_RATE = 50 * 1000;
const bool OLED_STARTUP_BUS_DIAG = false;
const bool OLED_DIAG_ENABLE_SWAPPED_SCAN = false;
const bool OLED_LIVE_PROBE_WHEN_ABSENT = true;
uint32_t current_i2c_baud = I2C_BAUD_RATE;

void init_i2c(uint32_t baud_rate = I2C_BAUD_RATE) {
  i2c_init(i2c0, baud_rate);
  current_i2c_baud = baud_rate;
  gpio_set_function(I2C_SDA_PIN, GPIO_FUNC_I2C);
  gpio_set_function(I2C_SCL_PIN, GPIO_FUNC_I2C);
  gpio_pull_up(I2C_SDA_PIN);
  gpio_pull_up(I2C_SCL_PIN);
  printf("I2C init baud=%lu\n", (unsigned long)baud_rate);
}

static void i2c_gpio_release(uint pin) {
  gpio_set_dir(pin, GPIO_IN);
  gpio_pull_up(pin);
}

static void i2c_gpio_drive_low(uint pin) {
  gpio_put(pin, 0);
  gpio_set_dir(pin, GPIO_OUT);
}

void recover_i2c_bus() {
  printf("I2C recovery start\n");
  i2c_deinit(i2c0);
  gpio_set_function(I2C_SDA_PIN, GPIO_FUNC_SIO);
  gpio_set_function(I2C_SCL_PIN, GPIO_FUNC_SIO);
  i2c_gpio_release(I2C_SDA_PIN);
  i2c_gpio_release(I2C_SCL_PIN);
  sleep_us(10);

  for (int i = 0; i < 9; ++i) {
    i2c_gpio_drive_low(I2C_SCL_PIN);
    sleep_us(10);
    i2c_gpio_release(I2C_SCL_PIN);
    sleep_us(10);
  }

  // STOP condition: SDA low while SCL is high, then release SDA.
  i2c_gpio_drive_low(I2C_SDA_PIN);
  sleep_us(10);
  i2c_gpio_release(I2C_SCL_PIN);
  sleep_us(10);
  i2c_gpio_release(I2C_SDA_PIN);
  sleep_us(10);
  printf("I2C recovery done sda=%d scl=%d\n",
         gpio_get(I2C_SDA_PIN), gpio_get(I2C_SCL_PIN));
}

bool oled_present = false;
bool oled_initialized = false;

static bool bb_probe(uint sda, uint scl, uint8_t addr7, uint us);

static int i2c_read_probe_addr(uint8_t addr) {
  uint8_t probe = 0;
  return i2c_read_timeout_us(i2c0, addr, &probe, (int)sizeof(probe), false,
                             5000);
}

static int oled_probe_ssd1306_nop() {
  uint8_t pkt[2] = {0x00, 0xE3}; // SSD1306 NOP command, harmless if ACKed.
  return i2c_write_timeout_us(i2c0, SSD1306_I2C_ADDR, pkt, (int)sizeof(pkt), false,
                              5000);
}

bool scan_i2c_bus(const char *phase = "scan") {
  printf("I2C scan start phase=%s\n", phase);
  bool found = false;
  bool found_oled = false;
  int devices = 0;

  for (uint8_t addr = 0x08; addr <= 0x77; ++addr) {
    // Use a harmless SSD1306 NOP for 0x3C: read probes can miss write-only
    // displays, while raw bit-bang probing perturbs the bus more than needed.
    int ret = -1;
    bool ack = false;
    if (addr == SSD1306_I2C_ADDR) {
      ret = oled_probe_ssd1306_nop();
      ack = (ret == 2);
    } else {
      ret = i2c_read_probe_addr(addr);
      ack = (ret >= 0);
    }
    if (ack) {
      printf("I2C device: 0x%02X\n", addr);
      found = true;
      ++devices;
      if (addr == SSD1306_I2C_ADDR) found_oled = true;
    }
    if (addr == SSD1306_I2C_ADDR) {
      printf("OLED_PROBE phase=%s addr=0x%02X ret=%d ack=%d\n",
             phase, addr, ret, ack ? 1 : 0);
    }
  }

  if (!found) {
    printf("I2C no devices\n");
  }
  oled_present = found_oled;
  if (!oled_present) oled_initialized = false;
  printf("I2C scan done phase=%s devices=%d oled=%d\n",
         phase, devices, found_oled ? 1 : 0);
  printf("OLED_DETECT phase=%s result=%s\n",
         phase, found_oled ? "present" : "absent");
  return found_oled;
}

bool detect_oled_with_recovery(const char *reason = "detect") {
  printf("OLED_DETECT_SEQUENCE reason=%s start\n", reason);
  if (scan_i2c_bus("initial")) {
    printf("OLED_DETECT_SEQUENCE reason=%s result=present stage=initial\n", reason);
    return true;
  }

  recover_i2c_bus();
  init_i2c(I2C_BAUD_RATE);
  if (scan_i2c_bus("after_bus_recovery_100k")) {
    printf("OLED_DETECT_SEQUENCE reason=%s result=present stage=after_bus_recovery_100k\n", reason);
    return true;
  }

  printf("I2C retry slower baud=%lu\n", (unsigned long)I2C_RECOVERY_BAUD_RATE);
  init_i2c(I2C_RECOVERY_BAUD_RATE);
  bool found = scan_i2c_bus("after_bus_recovery_50k");
  printf("OLED_DETECT_SEQUENCE reason=%s result=%s stage=after_bus_recovery_50k\n",
         reason, found ? "present" : "absent");
  return found;
}

// ---------------------------------------------------------------------------
// OLED bus diagnostics.
// Goal: distinguish "OLED electrically absent/dead" from "timing / slow-rise /
// miswiring" without touching wires. Emits structured DIAG lines over UART.
// ---------------------------------------------------------------------------
static bool bb_probe(uint sda, uint scl, uint8_t addr7, uint us) {
  // Open-drain bit-bang single-byte address probe. release()=input+pullup
  // (line floats high via pull-up), drive_low()=output 0. ACK = slave pulls
  // SDA low on the 9th clock. us is the bit half-period (large => very slow).
  gpio_set_function(sda, GPIO_FUNC_SIO);
  gpio_set_function(scl, GPIO_FUNC_SIO);
  i2c_gpio_release(sda); i2c_gpio_release(scl); sleep_us(us);
  // START: SDA high->low while SCL high
  i2c_gpio_drive_low(sda); sleep_us(us);
  i2c_gpio_drive_low(scl); sleep_us(us);
  uint8_t byte = (uint8_t)((addr7 << 1) | 0u);  // write
  for (int b = 7; b >= 0; --b) {
    if (byte & (1u << b)) i2c_gpio_release(sda); else i2c_gpio_drive_low(sda);
    sleep_us(us);
    i2c_gpio_release(scl); sleep_us(us);  // clock high (let slave sample)
    i2c_gpio_drive_low(scl); sleep_us(us);
  }
  // 9th clock = ACK: release SDA, clock high, read who pulls it low
  i2c_gpio_release(sda); sleep_us(us);
  i2c_gpio_release(scl); sleep_us(us);
  bool ack = (gpio_get(sda) == 0);
  i2c_gpio_drive_low(scl); sleep_us(us);
  // STOP: SDA low, SCL high, then SDA high
  i2c_gpio_drive_low(sda); sleep_us(us);
  i2c_gpio_release(scl); sleep_us(us);
  i2c_gpio_release(sda); sleep_us(us);
  return ack;
}

static int bb_scan(uint sda, uint scl, uint us, const char* tag) {
  int found = 0;
  bool ack3c = false;
  for (uint8_t a = 0x08; a <= 0x77; ++a) {
    if (bb_probe(sda, scl, a, us)) {
      printf("DIAG %s ACK addr=0x%02X\n", tag, a);
      found++;
      if (a == SSD1306_I2C_ADDR) ack3c = true;
    }
  }
  printf("DIAG %s done sda=%u scl=%u us=%u found=%d ack3c=%d\n",
         tag, sda, scl, us, found, ack3c ? 1 : 0);
  return found;
}

static int hw_scan_count(uint32_t baud) {
  init_i2c(baud);
  int found = 0;
  bool ack3c = false;
  for (uint8_t a = 0x08; a <= 0x77; ++a) {
    int ret = (a == SSD1306_I2C_ADDR) ? oled_probe_ssd1306_nop()
                                      : i2c_read_probe_addr(a);
    bool ack = (a == SSD1306_I2C_ADDR) ? (ret == 2) : (ret >= 0);
    if (ack) { found++; if (a == SSD1306_I2C_ADDR) ack3c = true; }
  }
  printf("DIAG hw baud=%lu found=%d ack3c=%d\n",
         (unsigned long)baud, found, ack3c ? 1 : 0);
  return found;
}

// Is a powered device present on the bus? A live SSD1306 module ties SDA/SCL
// to its VCC through onboard pull-ups (typ. 4.7k-10k). Enable ONLY the RP2040
// internal pull-DOWN (~50k) and read: an external pull-up to a powered rail
// wins the divider (reads 1); with no powered device the internal pull-down
// wins (reads 0). Then float (no pull) as a secondary hint.
static void bus_pullup_probe() {
  const uint pins[2] = {I2C_SDA_PIN, I2C_SCL_PIN};
  const char* names[2] = {"SDA", "SCL"};
  for (int i = 0; i < 2; ++i) {
    uint p = pins[i];
    gpio_set_function(p, GPIO_FUNC_SIO);
    gpio_set_dir(p, GPIO_IN);
    gpio_set_pulls(p, false, true);   // internal pull-down only
    sleep_us(300);
    int with_pd = gpio_get(p);
    gpio_set_pulls(p, false, false);  // float (high-Z)
    sleep_us(300);
    int floating = gpio_get(p);
    printf("DIAG pullup %s pin=%u with_internal_pulldown=%d floating=%d\n",
           names[i], p, with_pd, floating);
  }
}

// Fast live continuity monitor: prints SDA/SCL external-pull-up presence plus a
// single 0x3C bit-bang ACK probe, ~twice a second, so a human wiggling the SDA
// wire gets near-real-time feedback. sda_pu/scl_pu flip 0->1 the instant the
// pin sees the powered module's pull-up.
void live_probe() {
  gpio_set_function(I2C_SDA_PIN, GPIO_FUNC_SIO);
  gpio_set_dir(I2C_SDA_PIN, GPIO_IN);
  gpio_set_pulls(I2C_SDA_PIN, false, true);
  sleep_us(200);
  int sda_pu = gpio_get(I2C_SDA_PIN);
  gpio_set_function(I2C_SCL_PIN, GPIO_FUNC_SIO);
  gpio_set_dir(I2C_SCL_PIN, GPIO_IN);
  gpio_set_pulls(I2C_SCL_PIN, false, true);
  sleep_us(200);
  int scl_pu = gpio_get(I2C_SCL_PIN);
  bool ack = bb_probe(I2C_SDA_PIN, I2C_SCL_PIN, SSD1306_I2C_ADDR, 5);
  printf("LIVE sda_pu=%d scl_pu=%d ack3c=%d\n", sda_pu, scl_pu, ack ? 1 : 0);
}

void run_i2c_diagnostics() {
  printf("DIAG begin\n");
  bus_pullup_probe();   // external pull-up => powered module present on bus
  // (1) hardware-I2C speed sweep: does a slower clock change anything?
  hw_scan_count(400000);
  hw_scan_count(100000);
  hw_scan_count(50000);
  hw_scan_count(10000);
  // (2) bit-bang, normal mapping, very slow (us=100 => ~5kHz half-period).
  //     Half-period 100us dwarfs any plausible RC rise time, so a NACK here
  //     rules out slow-rise/timing as the cause.
  bb_scan(I2C_SDA_PIN, I2C_SCL_PIN, 100, "bb_norm_100us");
  // (3) even slower (us=500 => ~1kHz) for extreme margin.
  bb_scan(I2C_SDA_PIN, I2C_SCL_PIN, 500, "bb_norm_500us");
  // (4) Optional bit-bang with SDA/SCL swapped. This is useful only for an
  // explicit miswire check; do not run it in normal startup because it drives
  // non-I2C waveforms onto a correctly wired OLED.
  if (OLED_DIAG_ENABLE_SWAPPED_SCAN) {
    bb_scan(I2C_SCL_PIN, I2C_SDA_PIN, 100, "bb_swap_100us");
  }
  // Restore hardware I2C at the normal rate for the rest of the program.
  init_i2c(I2C_BAUD_RATE);
  printf("DIAG end\n");
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
bool oled_render(uint blink_cycles) {
  char count_line[16];
  snprintf(count_line, sizeof(count_line), "BLINK %u", blink_cycles);

  ssd1306_clear();
  ssd1306_draw_string(0, 0, "RP2040 PICO LAB");
  ssd1306_draw_string(0, 2, "I2C OLED OK");
  ssd1306_draw_string(0, 4, "ADDR 3C FOUND");
  ssd1306_draw_string(0, 6, count_line);
  uint16_t fbcrc = ssd1306_buf_crc();
  printf("OLED_RENDER start blink=%u fbcrc=0x%04X\n", blink_cycles, fbcrc);
  bool ok = ssd1306_show(i2c0);
  printf("OLED_RENDER result=%s blink=%u fbcrc=0x%04X\n",
         ok ? "ok" : "fail", blink_cycles, fbcrc);
  printf("OLED %s fbcrc=0x%04X\n", ok ? "updated" : "update failed", fbcrc);
  return ok;
}

bool ensure_oled_ready() {
  if (!oled_present) return false;
  if (!oled_initialized) {
    printf("OLED_READY init_required present=%d initialized=%d\n",
           oled_present ? 1 : 0, oled_initialized ? 1 : 0);
    oled_initialized = ssd1306_init(i2c0);
    printf("OLED init %s\n", oled_initialized ? "ok" : "failed");
    if (oled_initialized) {
      bool recover_ok = ssd1306_recover(i2c0);
      printf("OLED_READY post_init_recover result=%s\n",
             recover_ok ? "ok" : "fail");
      oled_initialized = recover_ok;
    }
    if (!oled_initialized) {
      oled_present = false;
    }
  }
  return oled_initialized;
}

bool update_oled_frame(uint blink_cycles) {
  if (!ensure_oled_ready()) return false;
  if (oled_render(blink_cycles)) return true;

  printf("OLED_RECOVER_TRIGGER reason=render_fail blink=%u\n", blink_cycles);
  recover_i2c_bus();
  init_i2c(I2C_BAUD_RATE);
  bool recover_ok = ssd1306_recover(i2c0);
  printf("OLED_RECOVER_TRIGGER result=%s\n", recover_ok ? "ok" : "fail");
  oled_initialized = recover_ok;
  oled_present = recover_ok;
  if (recover_ok) {
    return oled_render(blink_cycles);
  }
  return false;
}

int main() {
  stdio_init_all();
  gpio_init(LED_PIN);
  gpio_set_dir(LED_PIN, GPIO_OUT);
  init_i2c();
  if (OLED_STARTUP_BUS_DIAG) {
    run_i2c_diagnostics();
  }
  detect_oled_with_recovery("startup");
  run_post();

  update_oled_frame(0);

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
    update_oled_frame(blink_cycles);
    // Re-sample VSYS / temperature / VBUS every cycle so the plot stays live.
    sample_and_report();
    if (!oled_initialized) {
      if (OLED_LIVE_PROBE_WHEN_ABSENT) {
        live_probe();
      }
      init_i2c(I2C_BAUD_RATE);
      if (blink_cycles % 8 == 0) detect_oled_with_recovery("periodic_absent");
    }
  }
  return 0;
}
