#!/usr/bin/env bash
# Logic analyzer (I2C) capture entry point.
#
# Real path:  sigrok-cli + cheap FX2LP-class USB logic analyzer (fx2lafw).
#             Captures SCL/SDA, decodes I2C (address, ACK/NACK, data) and
#             saves the decode output as evidence.
# Stub path:  when sigrok-cli is not installed, copies the committed sample
#             decode (evidence/samples/i2c_nack_decode_sample.txt) so the
#             downstream pipeline can be exercised without hardware.
#
# Usage: scripts/capture_logic_i2c.sh [duration_ms]   (default: 6000)
#
# Default is 6s so the window spans bursty/periodic I2C activity (for example
# a bus scan that only re-runs every few seconds); a 1s window can miss it and
# produce a misleading "no decode" fail.
#
# Outputs:
#   evidence/latest/logic_i2c_decode.txt
#   evidence/latest/logic_i2c_result.json
# Exit code: 0 = pass or stub, 1 = fail
# pass means the expected SSD1306 address (0x3C) ACKed. A valid decode with
# only NACKs is real evidence, but it is still a failed OLED/I2C check.

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

DECODE_TXT="${EVIDENCE_DIR}/logic_i2c_decode.txt"
RESULT_JSON="${EVIDENCE_DIR}/logic_i2c_result.json"
DURATION_MS="${1:-6000}"

DRIVER="$(cfg_get logic_analyzer.device fx2lafw)"
CONN="$(cfg_get logic_analyzer.conn "")"
SAMPLE_RATE="$(cfg_get logic_analyzer.sample_rate "1 MHz")"
CH_SCL="$(cfg_get logic_analyzer.channels.scl 0)"
CH_SDA="$(cfg_get logic_analyzer.channels.sda 1)"

DRIVER_SPEC="${DRIVER}"
if [ -n "${CONN}" ]; then
    DRIVER_SPEC="${DRIVER}:conn=${CONN}"
fi

stub_result() {
    echo "== scripts/capture_logic_i2c.sh: STUB ($1) =="
    cp "${REPO_ROOT}/evidence/samples/i2c_nack_decode_sample.txt" "${DECODE_TXT}"
    write_result_json "${RESULT_JSON}" "logic_i2c" "stub" "$1" \
        "evidence/latest/logic_i2c_decode.txt"
    echo "== logic_i2c: stub (evidence/latest/logic_i2c_decode.txt) =="
    exit 0
}

# Safety gate: real capture runs only when explicitly enabled, separately
# from PICO_HARDWARE (a logic analyzer is its own piece of equipment).
if ! logic_capture_enabled i2c; then
    stub_result "logic analyzer I2C not enabled. Set PICO_LOGIC_I2C=1 to enable I2C capture, or PICO_LOGIC_ANALYZER=1 to enable all logic captures. Using sample decode output."
fi

if ! command -v sigrok-cli >/dev/null 2>&1; then
    stub_result "sigrok-cli not installed; copied sample decode for pipeline testing"
fi

echo "== scripts/capture_logic_i2c.sh: capturing ${DURATION_MS}ms via ${DRIVER_SPEC} =="
if sigrok-cli \
    --driver "${DRIVER_SPEC}" \
    --config "samplerate=${SAMPLE_RATE}" \
    --time "${DURATION_MS}ms" \
    --channels "D${CH_SCL}=SCL,D${CH_SDA}=SDA" \
    --protocol-decoders "i2c:scl=SCL:sda=SDA" \
    --protocol-decoder-annotations i2c 2>&1 | tee "${DECODE_TXT}"; then
    ANALYSIS_TSV="$(python3 - "${DECODE_TXT}" <<'PYEOF'
import json
import re
import sys

decode_path = sys.argv[1]
try:
    with open(decode_path, errors="ignore") as f:
        lines = [line.strip() for line in f]
except OSError:
    lines = []

annotation_re = re.compile(r"^i2c-\d+: (Start|Address|Data|ACK|NACK|Stop)")
addr_re = re.compile(r"^i2c-\d+: Address write: ([0-9A-Fa-f]{2})$")
result_re = re.compile(r"^i2c-\d+: (ACK|NACK)$")

transactions = []
pending = None
has_annotations = False
for line in lines:
    if annotation_re.search(line):
        has_annotations = True
    addr_match = addr_re.search(line)
    if addr_match:
        pending = {"address": int(addr_match.group(1), 16), "result": None}
        transactions.append(pending)
        continue
    result_match = result_re.search(line)
    if result_match and pending is not None and pending["result"] is None:
        pending["result"] = result_match.group(1)
        pending = None

address_count = len(transactions)
ack_count = sum(1 for tx in transactions if tx["result"] == "ACK")
nack_count = sum(1 for tx in transactions if tx["result"] == "NACK")
ssd1306_seen = sum(1 for tx in transactions if tx["address"] == 0x3C)
ssd1306_ack = sum(1 for tx in transactions if tx["address"] == 0x3C and tx["result"] == "ACK")
ssd1306_nack = sum(1 for tx in transactions if tx["address"] == 0x3C and tx["result"] == "NACK")

observations = {
    "annotations": int(has_annotations),
    "address_writes": address_count,
    "ack": ack_count,
    "nack": nack_count,
    "ssd1306_0x3c_seen": ssd1306_seen,
    "ssd1306_0x3c_ack": ssd1306_ack,
    "ssd1306_0x3c_nack": ssd1306_nack,
}

if ssd1306_ack:
    status = "pass"
    reason = ""
    health_hint = "ssd1306_i2c_ack_ok"
elif not has_annotations:
    status = "fail"
    reason = "no I2C decode annotations captured; check wiring, pull-ups, channel mapping, and target activity"
    health_hint = "i2c_decode_absent"
elif ssd1306_seen:
    status = "fail"
    reason = "SSD1306 address 0x3C was probed but NACKed; OLED is not responding"
    health_hint = "ssd1306_i2c_nack"
elif ack_count:
    status = "fail"
    reason = "I2C activity and ACKs were captured, but SSD1306 address 0x3C did not ACK"
    health_hint = "i2c_active_other_device"
else:
    status = "fail"
    reason = "I2C address scan captured but all observed addresses NACKed"
    health_hint = "i2c_active_all_nack"

print(status)
print(reason)
print(json.dumps({
    "observations": observations,
    "health_hint": health_hint,
}, separators=(",", ":")))
PYEOF
)"
    STATUS="$(printf '%s\n' "${ANALYSIS_TSV}" | sed -n '1p')"
    REASON="$(printf '%s\n' "${ANALYSIS_TSV}" | sed -n '2p')"
    ANALYSIS_JSON="$(printf '%s\n' "${ANALYSIS_TSV}" | sed -n '3p')"
else
    STATUS="fail"
    REASON="sigrok-cli capture failed (logic analyzer not connected?)"
    ANALYSIS_JSON=""
fi

write_result_json "${RESULT_JSON}" "logic_i2c" "${STATUS}" "${REASON}" "evidence/latest/logic_i2c_decode.txt" "${ANALYSIS_JSON:-}"

if [ -n "${REASON}" ]; then
    echo "Reason: ${REASON}"
fi
echo "== logic_i2c: ${STATUS} (log: evidence/latest/logic_i2c_decode.txt) =="
[ "${STATUS}" = "pass" ]
