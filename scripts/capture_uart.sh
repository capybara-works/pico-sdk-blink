#!/usr/bin/env bash
# UART capture entry point.
# Wraps the existing uart_monitor.py and saves the captured output as evidence.
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

UART_PORT="${PICO_UART_PORT:-$(cfg_get serial.port "")}"

if [ -z "${UART_PORT}" ]; then
    echo "SKIP: hardware not configured (set PICO_UART_PORT or serial.port in config/hardware.local.yaml)" | tee "${UART_LOG}"
    write_result_json "${RESULT_JSON}" "uart" "skip" "hardware not configured" "evidence/latest/uart.log"
    exit 0
fi

echo "== scripts/capture_uart.sh: capturing ${DURATION}s from ${UART_PORT} =="
if python3 "${REPO_ROOT}/uart_monitor.py" "${UART_PORT}" "${DURATION}" 2>&1 | tee "${UART_LOG}"; then
    STATUS="pass"
    REASON=""
else
    STATUS="fail"
    REASON="expected UART patterns not found; see evidence/latest/uart.log"
fi

write_result_json "${RESULT_JSON}" "uart" "${STATUS}" "${REASON}" "evidence/latest/uart.log"

echo "== uart: ${STATUS} (log: evidence/latest/uart.log) =="
[ "${STATUS}" = "pass" ]
