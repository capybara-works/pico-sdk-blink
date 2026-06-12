#!/usr/bin/env bash
# Build entry point.
# Wraps the existing build_and_test.sh (cmake configure / build / ctest /
# optional Wokwi test) and records the result under evidence/latest/.
#
# Outputs:
#   evidence/latest/build.log
#   evidence/latest/build_result.json
# Exit code: 0 = pass, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BUILD_LOG="${EVIDENCE_DIR}/build.log"
RESULT_JSON="${EVIDENCE_DIR}/build_result.json"

echo "== scripts/build.sh: running build_and_test.sh =="
if "${REPO_ROOT}/build_and_test.sh" 2>&1 | tee "${BUILD_LOG}"; then
    STATUS="pass"
else
    STATUS="fail"
fi

write_result_json "${RESULT_JSON}" "build" "${STATUS}" "" "evidence/latest/build.log"

echo "== build: ${STATUS} (log: evidence/latest/build.log) =="
[ "${STATUS}" = "pass" ]
