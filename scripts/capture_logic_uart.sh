#!/usr/bin/env bash
# Logic analyzer (UART TX) capture entry point.
#
# Real path:  sigrok-cli + cheap FX2LP-class USB logic analyzer (fx2lafw).
#             Captures Pico UART0 TX, decodes 115200 baud UART, and verifies
#             the expected LED on/off messages at the wire level.
# Stub path:  when disabled or sigrok-cli is unavailable, copies a committed
#             sample decode so the evidence pipeline can be exercised without
#             logic analyzer hardware.
#
# Usage: scripts/capture_logic_uart.sh [duration_ms]   (default: 3000)
#
# Outputs:
#   evidence/latest/logic_uart_decode.txt
#   evidence/latest/logic_uart_text.txt
#   evidence/latest/logic_uart_result.json
# Exit code: 0 = pass or stub, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

DECODE_TXT="${EVIDENCE_DIR}/logic_uart_decode.txt"
TEXT_TXT="${EVIDENCE_DIR}/logic_uart_text.txt"
RESULT_JSON="${EVIDENCE_DIR}/logic_uart_result.json"
DURATION_MS="${1:-3000}"

DRIVER="$(cfg_get logic_analyzer.device fx2lafw)"
CONN="$(cfg_get logic_analyzer.conn "")"
SAMPLE_RATE="$(cfg_get logic_analyzer.sample_rate "1 MHz")"
CH_UART_TX="$(cfg_get logic_analyzer.channels.uart_tx 2)"
BAUDRATE="$(cfg_get serial.baudrate 115200)"

DRIVER_SPEC="${DRIVER}"
if [ -n "${CONN}" ]; then
    DRIVER_SPEC="${DRIVER}:conn=${CONN}"
fi

stub_result() {
    echo "== scripts/capture_logic_uart.sh: STUB ($1) =="
    cp "${REPO_ROOT}/evidence/samples/logic_uart_decode_sample.txt" "${DECODE_TXT}"
    printf 'LED on\r\nLED off\r\n' > "${TEXT_TXT}"
    write_result_json "${RESULT_JSON}" "logic_uart" "stub" "$1" \
        "evidence/latest/logic_uart_decode.txt"
    echo "== logic_uart: stub (evidence/latest/logic_uart_decode.txt) =="
    exit 0
}

if ! logic_capture_enabled uart; then
    stub_result "logic analyzer UART not enabled. Set PICO_LOGIC_UART=1 to enable UART capture, or PICO_LOGIC_ANALYZER=1 to enable all logic captures. Using sample decode output."
fi

if ! command -v sigrok-cli >/dev/null 2>&1; then
    stub_result "sigrok-cli not installed; copied sample decode for pipeline testing"
fi

parse_uart_decode() {
    python3 - "$DECODE_TXT" "$TEXT_TXT" <<'PYEOF'
import json
import re
import sys

decode_path, text_path = sys.argv[1:3]
hex_bytes = []
with open(decode_path, errors="replace") as f:
    for line in f:
        match = re.match(r"^uart-\d+:\s+([0-9A-Fa-f]{2})\s*$", line)
        if match:
            hex_bytes.append(int(match.group(1), 16))

data = bytes(hex_bytes)
text = data.decode("ascii", errors="replace")
with open(text_path, "w", newline="") as f:
    f.write(text)

extra = {
    "decoded_bytes": len(data),
    "decoded_text": text,
}
print(json.dumps(extra, separators=(",", ":")))

if "LED on" not in text or "LED off" not in text:
    sys.exit(1)
PYEOF
}

echo "== scripts/capture_logic_uart.sh: capturing ${DURATION_MS}ms via ${DRIVER_SPEC} =="
: > "${DECODE_TXT}"
: > "${TEXT_TXT}"
if sigrok-cli \
    --driver "${DRIVER_SPEC}" \
    --config "samplerate=${SAMPLE_RATE}" \
    --time "${DURATION_MS}ms" \
    --channels "D${CH_UART_TX}=TX" \
    --protocol-decoders "uart:rx=TX:baudrate=${BAUDRATE}" \
    --protocol-decoder-annotations uart > "${DECODE_TXT}" 2>&1; then
    if EXTRA_JSON="$(parse_uart_decode)"; then
        STATUS="pass"
        REASON=""
    else
        STATUS="fail"
        REASON="expected UART text not captured; check GND, D${CH_UART_TX}->GP0 wiring, baudrate, and target activity"
        EXTRA_JSON=""
    fi
else
    STATUS="fail"
    REASON="sigrok-cli UART capture failed (logic analyzer not connected?)"
    EXTRA_JSON=""
    : > "${TEXT_TXT}"
fi

if [ -s "${TEXT_TXT}" ]; then
    echo "Decoded UART text preview:"
    sed -n '1,12p' "${TEXT_TXT}"
fi

write_result_json "${RESULT_JSON}" "logic_uart" "${STATUS}" "${REASON}" \
    "evidence/latest/logic_uart_decode.txt" "${EXTRA_JSON}"

if [ -n "${REASON}" ]; then
    echo "Reason: ${REASON}"
fi
echo "== logic_uart: ${STATUS} (log: evidence/latest/logic_uart_decode.txt) =="
[ "${STATUS}" = "pass" ]
