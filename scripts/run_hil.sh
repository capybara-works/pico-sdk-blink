#!/usr/bin/env bash
# HIL test entry point.
# Wraps the existing tools/hil/hil_runner.py (OpenOCD flash + UART pattern test).
# Skips cleanly when no hardware is configured, so this is always safe to run.
#
# The UART port comes from PICO_UART_PORT or config/hardware.local.yaml
# (serial.port). It is never hardcoded here.
#
# Outputs:
#   evidence/latest/hil.log
#   evidence/latest/hil_result.json
# Exit code: 0 = pass or skip, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

HIL_LOG="${EVIDENCE_DIR}/hil.log"
RESULT_JSON="${EVIDENCE_DIR}/hil_result.json"

hardware_gate "hil" "${RESULT_JSON}" "${HIL_LOG}"

UART_PORT="${PICO_UART_PORT:-$(cfg_get serial.port "")}"
ELF_PATH="$(target_elf_path)"
TEST_FILE="$(cfg_get target.test_scenario blink.test.yaml)"
INTERFACE_CFG="$(cfg_get debug.openocd_interface_cfg interface/cmsis-dap.cfg)"
TARGET_CFG="$(cfg_get debug.openocd_target_cfg target/rp2040.cfg)"

if [ -z "${UART_PORT}" ]; then
    echo "SKIP: hardware not configured (set PICO_UART_PORT or serial.port in config/hardware.local.yaml)" | tee "${HIL_LOG}"
    write_result_json "${RESULT_JSON}" "hil" "skip" "hardware not configured" "evidence/latest/hil.log"
    exit 0
fi

if ! command -v openocd >/dev/null 2>&1; then
    echo "SKIP: openocd not installed" | tee "${HIL_LOG}"
    write_result_json "${RESULT_JSON}" "hil" "skip" "openocd not installed" "evidence/latest/hil.log"
    exit 0
fi

echo "== scripts/run_hil.sh: running hil_runner.py (uart: ${UART_PORT}) =="
if python3 "${REPO_ROOT}/tools/hil/hil_runner.py" \
    --test "${REPO_ROOT}/${TEST_FILE}" \
    --elf "${ELF_PATH}" \
    --uart "${UART_PORT}" \
    --openocd-interface-cfg "${INTERFACE_CFG}" \
    --openocd-target-cfg "${TARGET_CFG}" 2>&1 | tee "${HIL_LOG}"; then
    STATUS="pass"
    REASON=""
else
    STATUS="fail"
    REASON="hil_runner.py failed; see evidence/latest/hil.log"
fi

write_result_json "${RESULT_JSON}" "hil" "${STATUS}" "${REASON}" "evidence/latest/hil.log"

echo "== hil: ${STATUS} (log: evidence/latest/hil.log) =="
[ "${STATUS}" = "pass" ]
