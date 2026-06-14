#!/usr/bin/env bash
# One-shot evidence loop: runs every verification entry point in order and
# generates evidence/latest/verification.md at the end.
#
# Safe by default: hardware steps (flash/HIL/UART/GDB) run only when
# PICO_HARDWARE=1 is set, and logic analyzer capture only when
# PICO_LOGIC_ANALYZER=1 is set; otherwise they record explicit skip/stub
# results. If the build fails, hardware steps are not attempted
# (flashing a stale ELF would produce misleading evidence).
#
# Usage:
#   scripts/verify_all.sh                        # no hardware touched
#   PICO_HARDWARE=1 scripts/verify_all.sh        # real flash/HIL/UART/GDB
#   PICO_HARDWARE=1 PICO_LOGIC_ANALYZER=1 scripts/verify_all.sh
# Optional arg: [uart_duration_seconds] (default: 5)
# Exit code: 0 = no step failed (pass/skip/stub), 1 = at least one failure

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
UART_DURATION="${1:-5}"
FAILED=0

reset_evidence_dir

if ! "${SCRIPT_DIR}/build.sh"; then
    echo "== verify_all: build failed; skipping hardware steps =="
    python3 "${SCRIPT_DIR}/summarize_evidence.py"
    exit 1
fi

"${SCRIPT_DIR}/flash.sh"            || FAILED=1
"${SCRIPT_DIR}/run_hil.sh"          || FAILED=1
"${SCRIPT_DIR}/capture_uart.sh" "${UART_DURATION}" || FAILED=1
"${SCRIPT_DIR}/gdb_snapshot.sh"     || FAILED=1
"${SCRIPT_DIR}/capture_logic_uart.sh" || FAILED=1
"${SCRIPT_DIR}/capture_logic_i2c.sh"  || FAILED=1

python3 "${SCRIPT_DIR}/summarize_evidence.py" || FAILED=1

exit ${FAILED}
