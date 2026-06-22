#!/usr/bin/env bash
# UART capture entry point.
# Wraps the existing tools/hil/uart_monitor.py and saves the captured output as evidence.
# Skips cleanly when no hardware is configured.
#
# Usage: scripts/capture_uart.sh [duration_seconds]   (default: 5)
#
# Outputs:
#   evidence/latest/uart.log
#   evidence/latest/uart_result.json
# Exit code: 0 = pass or skip, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

UART_LOG="${EVIDENCE_DIR}/uart.log"
RESULT_JSON="${EVIDENCE_DIR}/uart_result.json"
DURATION="${1:-5}"

hardware_gate "uart" "${RESULT_JSON}" "${UART_LOG}"

UART_PORT="${PICO_UART_PORT:-$(cfg_get serial.port "")}"

if [ -z "${UART_PORT}" ]; then
    echo "SKIP: hardware not configured (set PICO_UART_PORT or serial.port in config/hardware.local.yaml)" | tee "${UART_LOG}"
    write_result_json "${RESULT_JSON}" "uart" "skip" "hardware not configured" "evidence/latest/uart.log"
    exit 0
fi

echo "== scripts/capture_uart.sh: capturing ${DURATION}s from ${UART_PORT} =="
if python3 "${REPO_ROOT}/tools/hil/uart_monitor.py" "${UART_PORT}" "${DURATION}" 2>&1 | tee "${UART_LOG}"; then
    STATUS="pass"
    REASON=""
else
    STATUS="fail"
    REASON="expected UART patterns not found; see evidence/latest/uart.log"
fi

ANALYSIS_JSON="$(python3 - "${UART_LOG}" <<'PYEOF'
import json
import re
import sys

log_path = sys.argv[1]
try:
    with open(log_path, errors="ignore") as f:
        lines = f.readlines()
except OSError:
    lines = []

firmware_lines = [
    line.split("] ", 1)[1].strip()
    for line in lines
    if line.startswith("[") and "] " in line
]
non_nul_firmware_lines = [
    line for line in firmware_lines
    if line.replace("\x00", "").strip()
]
nul_only_lines = len(firmware_lines) - len(non_nul_firmware_lines)

def count(pattern):
    return sum(1 for line in firmware_lines if pattern in line)

live_lines = [line for line in firmware_lines if line.startswith("LIVE ")]

bad_re = re.compile(
    r"(i2c_oled=0|I2C no devices|OLED_I2C_ERROR|OLED_SHOW result=fail|"
    r"OLED_RENDER result=fail|OLED_RECOVER result=fail|lockup|HardFault|"
    r"panic|abort|FAIL|ERROR|Error)"
)
observations = {
    "lines": len(firmware_lines),
    "non_nul_lines": len(non_nul_firmware_lines),
    "nul_only_lines": nul_only_lines,
    "led_on": count("LED on"),
    "led_off": count("LED off"),
    "post_i2c_oled_ok": sum(1 for line in firmware_lines if line.startswith("POST ") and "i2c_oled=1" in line),
    "oled_updates": count("OLED updated"),
    "oled_show_ok": count("OLED_SHOW result=ok"),
    "oled_show_fail": count("OLED_SHOW result=fail"),
    "oled_i2c_errors": count("OLED_I2C_ERROR"),
    "oled_i2c_retries": count("OLED_I2C_RETRY"),
    "oled_i2c_retry_fail": sum(1 for line in firmware_lines if line.startswith("OLED_I2C_RETRY ") and "ok=0" in line),
    "oled_recover_ok": count("OLED_RECOVER result=ok"),
    "oled_recover_fail": count("OLED_RECOVER result=fail"),
    "oled_probe_ack": sum(1 for line in firmware_lines if line.startswith("OLED_PROBE ") and "ack=1" in line),
    "oled_probe_nack": sum(1 for line in firmware_lines if line.startswith("OLED_PROBE ") and "ack=0" in line),
    "live_sda_pu_high": sum(1 for line in live_lines if "sda_pu=1" in line),
    "live_sda_pu_low": sum(1 for line in live_lines if "sda_pu=0" in line),
    "live_scl_pu_high": sum(1 for line in live_lines if "scl_pu=1" in line),
    "live_scl_pu_low": sum(1 for line in live_lines if "scl_pu=0" in line),
    "live_ack3c": sum(1 for line in live_lines if "ack3c=1" in line),
    "i2c_0x3c_seen": count("I2C device: 0x3C"),
    "bad_markers": sum(1 for line in firmware_lines if bad_re.search(line)),
}

if (
    observations["post_i2c_oled_ok"]
    and observations["oled_updates"]
    and observations["oled_show_ok"]
    and observations["oled_i2c_errors"] == 0
    and observations["bad_markers"] == 0
):
    health_hint = "oled_i2c_ok"
elif observations["live_sda_pu_low"] and observations["live_scl_pu_low"]:
    health_hint = "oled_bus_pullup_missing"
elif observations["live_sda_pu_low"] and observations["live_scl_pu_high"]:
    health_hint = "oled_sda_pullup_missing"
elif observations["live_scl_pu_low"] and observations["live_sda_pu_high"]:
    health_hint = "oled_scl_pullup_missing"
elif observations["oled_probe_nack"] and observations["oled_probe_ack"] == 0:
    health_hint = "oled_i2c_nack"
elif observations["oled_i2c_errors"] or observations["oled_show_fail"] or observations["oled_i2c_retry_fail"]:
    health_hint = "oled_i2c_write_fail"
elif observations["led_on"] and observations["led_off"]:
    health_hint = "led_uart_ok_oled_unproven"
elif observations["nul_only_lines"] and observations["non_nul_lines"] == 0:
    health_hint = "uart_nul_only"
elif observations["lines"]:
    health_hint = "uart_active_patterns_missing"
else:
    health_hint = "uart_silent"

health_notes = {
    "oled_i2c_ok": "OLED was detected and page writes completed by I2C return value.",
    "oled_bus_pullup_missing": "Neither SDA nor SCL external pull-up is visible to the Pico live probe; check OLED power, common ground, and the off-chip I2C path.",
    "oled_sda_pullup_missing": "SCL external pull-up is visible but SDA external pull-up is not; this can be an SDA path issue, missing/weak module pull-up, OLED power/module fault, or controller/input damage.",
    "oled_scl_pullup_missing": "SDA external pull-up is visible but SCL external pull-up is not; check the SCL path, module pull-up, OLED power, and analyzer/channel loading.",
    "oled_i2c_nack": "The firmware is probing 0x3C but the OLED is not acknowledging.",
    "oled_i2c_write_fail": "OLED was detected but later command/data writes failed or retries exhausted.",
    "led_uart_ok_oled_unproven": "Firmware LED/UART loop is alive, but OLED success was not proven in this capture.",
    "uart_nul_only": "Only NUL bytes were captured from the Debug Probe USB serial path; treat this UART observation as untrusted and corroborate with GDB or logic-analyzer UART.",
    "uart_active_patterns_missing": "UART is active but expected health patterns were incomplete.",
    "uart_silent": "No timestamped firmware UART lines were captured.",
}

print(json.dumps({
    "observations": observations,
    "health_hint": health_hint,
    "health_note": health_notes.get(health_hint, ""),
}, separators=(",", ":")))
PYEOF
)"

write_result_json "${RESULT_JSON}" "uart" "${STATUS}" "${REASON}" "evidence/latest/uart.log" "${ANALYSIS_JSON}"

echo "== uart: ${STATUS} (log: evidence/latest/uart.log) =="
[ "${STATUS}" = "pass" ]
