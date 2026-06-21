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

def count(pattern):
    return sum(1 for line in lines if pattern in line)

bad_re = re.compile(r"(i2c_oled=0|I2C no devices|lockup|HardFault|panic|abort|FAIL|Error)")
observations = {
    "lines": len(lines),
    "led_on": count("LED on"),
    "led_off": count("LED off"),
    "post_i2c_oled_ok": sum(1 for line in lines if "POST " in line and "i2c_oled=1" in line),
    "oled_updates": count("OLED updated"),
    "i2c_0x3c_seen": count("I2C device: 0x3C"),
    "bad_markers": sum(1 for line in lines if bad_re.search(line)),
}

if observations["post_i2c_oled_ok"] and observations["oled_updates"] and observations["bad_markers"] == 0:
    health_hint = "oled_i2c_ok"
elif observations["led_on"] and observations["led_off"]:
    health_hint = "led_uart_ok_oled_unproven"
elif observations["lines"]:
    health_hint = "uart_active_patterns_missing"
else:
    health_hint = "uart_silent"

print(json.dumps({
    "observations": observations,
    "health_hint": health_hint,
}, separators=(",", ":")))
PYEOF
)"

write_result_json "${RESULT_JSON}" "uart" "${STATUS}" "${REASON}" "evidence/latest/uart.log" "${ANALYSIS_JSON}"

echo "== uart: ${STATUS} (log: evidence/latest/uart.log) =="
[ "${STATUS}" = "pass" ]
