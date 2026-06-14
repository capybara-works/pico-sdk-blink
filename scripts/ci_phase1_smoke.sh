#!/usr/bin/env bash
# CI smoke test for the Phase 1 evidence pipeline. Requires no hardware.
#
# Runs the full verification loop WITHOUT PICO_HARDWARE / PICO_LOGIC_ANALYZER
# and asserts that:
#   - the build and CTest pass, optional Wokwi is recorded, and
#     verification.md is generated
#   - hardware steps (flash/hil/uart/gdb) are recorded as "skip", proving
#     the safety gates hold (no hardware operation without explicit opt-in)
#   - logic analyzer steps are "stub" or "skip", never a fake "pass"
#
# Note: skip/stub here means "not executed" — this smoke test verifies the
# evidence pipeline itself, NOT hardware behavior.
#
# Exit code: 0 = pipeline intact, 1 = broken

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
EVIDENCE_DIR="${REPO_ROOT}/evidence/latest"

# Make sure the gates are NOT enabled, even if set in the caller's env.
unset PICO_HARDWARE PICO_LOGIC_ANALYZER

echo "== ci_phase1_smoke: running verify_all.sh without hardware gates =="
if ! "${SCRIPT_DIR}/verify_all.sh"; then
    echo "ci_phase1_smoke: FAIL - verify_all.sh reported a failure"
    exit 1
fi

echo "== ci_phase1_smoke: asserting evidence statuses =="
python3 - "${EVIDENCE_DIR}" <<'PYEOF'
import json, os, sys

evidence_dir = sys.argv[1]
expected = {
    "build_result.json": {"pass"},
    "ctest_result.json": {"pass"},
    "wokwi_result.json": {"pass", "skip"},
    "flash_result.json": {"skip"},
    "hil_result.json": {"skip"},
    "uart_result.json": {"skip"},
    "gdb_snapshot.json": {"skip"},
    "logic_uart_result.json": {"stub", "skip"},
    "logic_i2c_result.json": {"stub", "skip"},
}
failures = []

for fname, allowed in expected.items():
    path = os.path.join(evidence_dir, fname)
    if not os.path.exists(path):
        failures.append(f"{fname}: missing")
        continue
    status = json.load(open(path)).get("status")
    if status not in allowed:
        failures.append(f"{fname}: status '{status}', expected one of {sorted(allowed)}")

if not os.path.exists(os.path.join(evidence_dir, "verification.md")):
    failures.append("verification.md: not generated")

if failures:
    print("ci_phase1_smoke: FAIL")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)

print("ci_phase1_smoke: OK")
print("  - build/ctest: pass (executed)")
print("  - wokwi: pass/skip (depending on token/tool availability)")
print("  - flash/hil/uart/gdb: skip (safety gates held; not executed)")
print("  - logic_uart/logic_i2c: stub/skip (not measured)")
print("  - verification.md generated")
PYEOF
