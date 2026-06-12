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
# Usage: scripts/capture_logic_i2c.sh [duration_ms]   (default: 1000)
#
# Outputs:
#   evidence/latest/logic_i2c_decode.txt
#   evidence/latest/logic_i2c_result.json
# Exit code: 0 = pass or stub, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

DECODE_TXT="${EVIDENCE_DIR}/logic_i2c_decode.txt"
RESULT_JSON="${EVIDENCE_DIR}/logic_i2c_result.json"
DURATION_MS="${1:-1000}"

DRIVER="$(cfg_get logic_analyzer.device fx2lafw)"
SAMPLE_RATE="$(cfg_get logic_analyzer.sample_rate "1 MHz")"
CH_SCL="$(cfg_get logic_analyzer.channels.scl 0)"
CH_SDA="$(cfg_get logic_analyzer.channels.sda 1)"

if ! command -v sigrok-cli >/dev/null 2>&1; then
    echo "== scripts/capture_logic_i2c.sh: STUB (sigrok-cli not installed) =="
    cp "${REPO_ROOT}/evidence/samples/i2c_nack_decode_sample.txt" "${DECODE_TXT}"
    write_result_json "${RESULT_JSON}" "logic_i2c" "stub" \
        "sigrok-cli not installed; copied sample decode for pipeline testing" \
        "evidence/latest/logic_i2c_decode.txt"
    echo "== logic_i2c: stub (evidence/latest/logic_i2c_decode.txt) =="
    exit 0
fi

echo "== scripts/capture_logic_i2c.sh: capturing ${DURATION_MS}ms via ${DRIVER} =="
if sigrok-cli \
    --driver "${DRIVER}" \
    --config "samplerate=${SAMPLE_RATE}" \
    --time "${DURATION_MS}" \
    --channels "D${CH_SCL}=SCL,D${CH_SDA}=SDA" \
    --protocol-decoders "i2c:scl=SCL:sda=SDA" \
    --protocol-decoder-annotations i2c 2>&1 | tee "${DECODE_TXT}"; then
    STATUS="pass"
    REASON=""
else
    STATUS="fail"
    REASON="sigrok-cli capture failed (logic analyzer not connected?)"
fi

write_result_json "${RESULT_JSON}" "logic_i2c" "${STATUS}" "${REASON}" "evidence/latest/logic_i2c_decode.txt"

echo "== logic_i2c: ${STATUS} (log: evidence/latest/logic_i2c_decode.txt) =="
[ "${STATUS}" = "pass" ]
