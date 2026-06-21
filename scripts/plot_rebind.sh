#!/usr/bin/env bash
# Rebind the real-time plot (Embedder Monitor) to the live Teleplot stream.
#
# WHY: when a serial monitor already holds the CMSIS-DAP CDC port, a freshly
# started plot can show "Channels (0)" / "no serial data received" because the
# single UART stream is being drained by the monitor. Resetting the target
# emits a fresh boot burst that rebinds to the most-recent subscriber (the plot).
#
# Usage:
#   1. Start the plot in the Embedder Monitor first.
#   2. Run with PICO_HARDWARE=1 to reset the Pico so telemetry rebinds to the plot.
#
# See docs/guides/DEBUGGING_AND_ANALYSIS.md section 5.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"
cd "${REPO_ROOT}"

if [ "${PICO_HARDWARE:-0}" != "1" ]; then
    echo "SKIP: hardware not enabled. Set PICO_HARDWARE=1 to rebind plot telemetry."
    exit 0
fi

INTERFACE_CFG="$(cfg_get debug.openocd_interface_cfg "${PICO_OPENOCD_INTERFACE_CFG:-interface/cmsis-dap.cfg}")"
TARGET_CFG="$(cfg_get debug.openocd_target_cfg "${PICO_OPENOCD_TARGET_CFG:-target/rp2040.cfg}")"

if ! command -v openocd >/dev/null 2>&1; then
    echo "SKIP: openocd not installed."
    exit 0
fi

echo "== Resetting target to rebind telemetry to the plot =="
openocd \
    -f "${INTERFACE_CFG}" \
    -c "transport select swd; adapter speed 1000" \
    -f "${TARGET_CFG}" \
    -c "init; reset run; exit"

echo "== Done. Telemetry should now populate the plot panel. =="
