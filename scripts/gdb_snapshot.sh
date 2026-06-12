#!/usr/bin/env bash
# GDB snapshot entry point.
# Attaches to the running target via OpenOCD (gdb_port pipe, so no port
# conflicts), halts core0, captures registers and a backtrace, resumes,
# then verifies the target is actually running again.
#
# RP2040-specific pitfalls this script works around (verified on hardware):
# - `set USE_CORE 0`: with the default dual-core config, the GDB pipe ends up
#   attached to core1. Halting core1 freezes the RP2040 TIMER (DBGPAUSE),
#   which makes sleep_ms() on core0 spin forever — the app appears dead.
# - `gdb_memory_map disable`: otherwise OpenOCD runs a flash-probe algorithm
#   on the target CPU during GDB connect, destroying the live register state
#   and leaving the core at a bootrom breakpoint.
# - Post-check phase: confirms core0 is running after detach; tries resume,
#   then falls back to `reset run` so the system is never left wedged.
#
# Notes on RP2040 (Cortex-M0+): there are no CFSR/HFSR/BFAR fault status
# registers (those are ARMv7-M). Fault context is derived from the xPSR
# exception number (IPSR field): 3 = HardFault.
#
# Outputs:
#   evidence/latest/gdb_snapshot.log   (raw GDB + restore-phase output)
#   evidence/latest/gdb_snapshot.json
# Exit code: 0 = pass or skip, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SNAPSHOT_LOG="${EVIDENCE_DIR}/gdb_snapshot.log"
RESULT_JSON="${EVIDENCE_DIR}/gdb_snapshot.json"

ELF_PATH="${REPO_ROOT}/$(cfg_get target.elf build/blink.elf)"
INTERFACE_CFG="$(cfg_get debug.openocd_interface_cfg interface/cmsis-dap.cfg)"
TARGET_CFG="$(cfg_get debug.openocd_target_cfg target/rp2040.cfg)"

skip() {
    echo "SKIP: $1" | tee "${SNAPSHOT_LOG}"
    write_result_json "${RESULT_JSON}" "gdb" "skip" "$1" "evidence/latest/gdb_snapshot.log"
    exit 0
}

[ "${PICO_HARDWARE:-0}" = "1" ] || skip "hardware not enabled. Set PICO_HARDWARE=1 to enable hardware operations."
command -v openocd >/dev/null 2>&1 || skip "openocd not installed"
command -v arm-none-eabi-gdb >/dev/null 2>&1 || skip "arm-none-eabi-gdb not installed"
[ -f "${ELF_PATH}" ] || skip "ELF not found: ${ELF_PATH} (run scripts/build.sh first)"

OPENOCD_ARGS=(-f "${INTERFACE_CFG}" -c "transport select swd; adapter speed 1000" -c "set USE_CORE 0" -f "${TARGET_CFG}")

echo "== scripts/gdb_snapshot.sh: capturing register snapshot from live target (core0) =="
arm-none-eabi-gdb -batch -nx "${ELF_PATH}" \
    -ex "target extended-remote | openocd -f ${INTERFACE_CFG} -c 'transport select swd; adapter speed 1000' -c 'set USE_CORE 0' -f ${TARGET_CFG} -c 'gdb_port pipe; gdb_memory_map disable; log_output /dev/null'" \
    -ex "monitor halt" \
    -ex "info registers" \
    -ex "bt" \
    -ex "detach" \
    2>&1 | tee "${SNAPSHOT_LOG}"

echo "== verifying target resumed =="
RESTORE_TCL='set st [rp2040.core0 curstate]
echo "core0 state after snapshot: $st"
if {$st ne "running"} {
    resume
    sleep 200
    set st [rp2040.core0 curstate]
    echo "core0 state after resume: $st"
    if {$st ne "running"} {
        reset run
        echo "core0 recovery: issued reset run"
    }
}'
openocd "${OPENOCD_ARGS[@]}" -c "init" -c "${RESTORE_TCL}" -c "shutdown" \
    2>&1 | tee -a "${SNAPSHOT_LOG}"

# Parse the raw GDB output into the JSON schema introduced by the stub.
python3 - "${SNAPSHOT_LOG}" "${RESULT_JSON}" <<'PYEOF'
import json, re, sys
from datetime import datetime, timezone

log_path, out_path = sys.argv[1], sys.argv[2]
with open(log_path) as f:
    log = f.read()

registers = {}
for name in ("pc", "lr", "sp", "xpsr"):
    m = re.search(rf"^{name}\s+(0x[0-9a-fA-F]+)", log, re.MULTILINE | re.IGNORECASE)
    registers[name] = m.group(1) if m else None

def region(addr_hex):
    if not addr_hex:
        return None
    addr = int(addr_hex, 16)
    if addr < 0x10000000:
        return "bootrom"
    if addr < 0x20000000:
        return "flash"
    if addr < 0x30000000:
        return "sram"
    return "other"

backtrace = re.findall(r"^#\d+ .*$", log, re.MULTILINE)

fault = None
if registers["xpsr"]:
    exception = int(registers["xpsr"], 16) & 0x3F  # IPSR field
    fault = {
        "exception_number": exception,
        "in_handler": exception != 0,
        "hard_fault": exception == 3,
    }

states = re.findall(r"core0 state after \w+: (\w+)", log)
resumed = bool(states) and states[-1] == "running"
reset_issued = "issued reset run" in log

ok = all(registers[r] for r in ("pc", "lr", "sp", "xpsr")) and (resumed or reset_issued)
result = {
    "step": "gdb",
    "status": "pass" if ok else "fail",
    "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "registers": registers,
    "pc_region": region(registers["pc"]),
    "fault": fault,
    "backtrace": backtrace,
    "target_resumed": resumed,
    "recovered_by_reset": reset_issued,
    "log": "evidence/latest/gdb_snapshot.log",
}
if not ok:
    result["reason"] = ("could not read core registers (debug probe not connected?)"
                        if not registers["pc"] else "target did not return to running state")

with open(out_path, "w") as f:
    json.dump(result, f, indent=2)
    f.write("\n")

print(f"== gdb: {result['status']} (evidence/latest/gdb_snapshot.json) ==")
sys.exit(0 if ok else 1)
PYEOF
