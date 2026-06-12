#!/usr/bin/env bash
# Build entry point.
# Runs firmware build, CTest, and optional Wokwi scenario test, then records the
# combined result under evidence/latest/.
#
# Outputs:
#   evidence/latest/build.log
#   evidence/latest/build_result.json
# Exit code: 0 = pass, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BUILD_LOG="${EVIDENCE_DIR}/build.log"
RESULT_JSON="${EVIDENCE_DIR}/build_result.json"

run_build_steps() {
    "${REPO_ROOT}/scripts/build_firmware.sh" || return $?
    "${REPO_ROOT}/scripts/test_ctest.sh" || return $?
    "${REPO_ROOT}/scripts/test_wokwi.sh" || return $?
}

echo "== scripts/build.sh: running build_firmware + ctest + optional Wokwi =="
if run_build_steps 2>&1 | tee "${BUILD_LOG}"; then
    STATUS="pass"
else
    STATUS="fail"
fi

write_result_json "${RESULT_JSON}" "build" "${STATUS}" "" "evidence/latest/build.log"

echo "== build: ${STATUS} (log: evidence/latest/build.log) =="
[ "${STATUS}" = "pass" ]
