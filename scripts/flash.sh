#!/usr/bin/env bash
# Flash entry point.
# Flashes the firmware ELF to a Pico via OpenOCD + Debug Probe (CMSIS-DAP),
# matching the method already used by hil_runner.py.
#
# Configuration comes from config/hardware.local.yaml (see hardware.example.yaml).
#
# Outputs:
#   evidence/latest/flash.log
#   evidence/latest/flash_result.json
# Exit code: 0 = pass or skip, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

FLASH_LOG="${EVIDENCE_DIR}/flash.log"
RESULT_JSON="${EVIDENCE_DIR}/flash_result.json"

ELF_PATH="${REPO_ROOT}/$(cfg_get target.elf build/blink.elf)"
INTERFACE_CFG="$(cfg_get debug.openocd_interface_cfg interface/cmsis-dap.cfg)"
TARGET_CFG="$(cfg_get debug.openocd_target_cfg target/rp2040.cfg)"

if ! command -v openocd >/dev/null 2>&1; then
    echo "SKIP: openocd not installed" | tee "${FLASH_LOG}"
    write_result_json "${RESULT_JSON}" "flash" "skip" "openocd not installed" "evidence/latest/flash.log"
    exit 0
fi

if [ ! -f "${ELF_PATH}" ]; then
    echo "FAIL: ELF not found: ${ELF_PATH} (run scripts/build.sh first)" | tee "${FLASH_LOG}"
    write_result_json "${RESULT_JSON}" "flash" "fail" "ELF not found: ${ELF_PATH}" "evidence/latest/flash.log"
    exit 1
fi

echo "== scripts/flash.sh: flashing ${ELF_PATH} via OpenOCD =="
if openocd \
    -f "${INTERFACE_CFG}" \
    -c "transport select swd; adapter speed 1000" \
    -f "${TARGET_CFG}" \
    -c "program ${ELF_PATH} verify reset exit" 2>&1 | tee "${FLASH_LOG}"; then
    STATUS="pass"
    REASON=""
else
    STATUS="fail"
    REASON="openocd program failed (debug probe not connected?)"
fi

write_result_json "${RESULT_JSON}" "flash" "${STATUS}" "${REASON}" "evidence/latest/flash.log"

echo "== flash: ${STATUS} (log: evidence/latest/flash.log) =="
[ "${STATUS}" = "pass" ]
