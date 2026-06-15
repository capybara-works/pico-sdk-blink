#!/usr/bin/env bash
# Target reset entry point (utility).
#
# Resets the target via OpenOCD + Debug Probe so the firmware re-runs from the
# top -- handy for re-triggering the boot Power-On Self-Test (the "POST ..."
# UART line) without reflashing. Pair with scripts/capture_uart.sh to read the
# fresh POST snapshot.
#
# This is a small operator utility, not a verification step: it intentionally
# writes no *_result.json and stays out of verify_all / the summary.
#
# Gate: hardware action -> requires PICO_HARDWARE=1 (AI must not self-enable;
# see docs/operations/AGENT_OPERATION.md).
#
# Exit code: 0 = reset or cleanly skipped, 1 = reset failed.

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [ "${PICO_HARDWARE:-0}" != "1" ]; then
    echo "SKIP: hardware not enabled. Set PICO_HARDWARE=1 to reset the target."
    exit 0
fi

if ! command -v openocd >/dev/null 2>&1; then
    echo "SKIP: openocd not installed."
    exit 0
fi

INTERFACE_CFG="$(cfg_get debug.openocd_interface_cfg interface/cmsis-dap.cfg)"
TARGET_CFG="$(cfg_get debug.openocd_target_cfg target/rp2040.cfg)"

echo "== scripts/reset_target.sh: resetting target via OpenOCD =="
if openocd \
    -f "${INTERFACE_CFG}" \
    -c "transport select swd; adapter speed 1000" \
    -f "${TARGET_CFG}" \
    -c "init; reset run; exit"; then
    echo "== reset: done (firmware restarted; read POST via scripts/capture_uart.sh) =="
else
    echo "FAIL: openocd reset failed (debug probe not connected?)"
    exit 1
fi
