#!/usr/bin/env bash
# Low-level optional Wokwi scenario test.
# Exits 0 when Wokwi is intentionally unavailable, preserving local ergonomics.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"
ELF_PATH="$(build_artifact_path "blink.elf")"
SCENARIO="${PICO_WOKWI_SCENARIO:-blink_i2c.test.yaml}"
WOKWI_TIMEOUT_MS="${PICO_WOKWI_TIMEOUT_MS:-10000}"

case "${SCENARIO}" in
    /*) SCENARIO_PATH="${SCENARIO}" ;;
    *) SCENARIO_PATH="${REPO_ROOT}/${SCENARIO}" ;;
esac

echo "== Run Wokwi Test (Optional) =="
if [ -z "${WOKWI_CLI_TOKEN:-}" ]; then
    echo "SKIP: WOKWI_CLI_TOKEN is not set."
    echo "To run Wokwi tests locally, set WOKWI_CLI_TOKEN and install wokwi-cli."
    exit 0
fi

if command -v wokwi-cli >/dev/null 2>&1; then
    WOKWI_CMD=(wokwi-cli)
else
    echo "SKIP: wokwi-cli not found."
    echo "Install Wokwi CLI with: curl -L https://wokwi.com/ci/install.sh | sh"
    exit 0
fi

if [ ! -f "${ELF_PATH}" ]; then
    echo "FAIL: Wokwi ELF not found: ${ELF_PATH} (run scripts/build_firmware.sh first)"
    exit 1
fi

if [ ! -f "${SCENARIO_PATH}" ]; then
    echo "FAIL: Wokwi scenario not found: ${SCENARIO_PATH}"
    exit 1
fi

echo "Running Wokwi test with ${WOKWI_CMD[*]}..."
echo "Using ELF: ${ELF_PATH}"
echo "Using scenario: ${SCENARIO_PATH}"
echo "Using timeout: ${WOKWI_TIMEOUT_MS}ms"
"${WOKWI_CMD[@]}" "${REPO_ROOT}" --elf "${ELF_PATH}" --scenario "${SCENARIO_PATH}" --timeout "${WOKWI_TIMEOUT_MS}"
