#!/usr/bin/env bash
# Record the GitHub Actions Wokwi CI action outcome as evidence.
#
# Usage:
#   scripts/record_wokwi_ci_result.sh <action_outcome> [scenario]
#
# This script always exits 0 so workflows can upload the evidence artifact
# before a later step fails the job when the Wokwi action did not succeed.

set -u
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

WOKWI_LOG="${EVIDENCE_DIR}/wokwi.log"
RESULT_JSON="${EVIDENCE_DIR}/wokwi_result.json"
OUTCOME="${1:-unknown}"
SCENARIO="${2:-blink_i2c.test.yaml}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-unknown}/actions/runs/${GITHUB_RUN_ID:-unknown}"
EXTRA_JSON="$(python3 - "${SCENARIO}" "${RUN_URL}" <<'PYEOF'
import json
import sys

scenario, run_url = sys.argv[1:3]
print(json.dumps({"wokwi": {"scenario": scenario, "run_url": run_url}}, separators=(",", ":")))
PYEOF
)"

case "${OUTCOME}" in
    success)
        STATUS="pass"
        REASON="wokwi-ci-action completed successfully"
        ;;
    skipped)
        STATUS="skip"
        REASON="wokwi-ci-action was skipped"
        ;;
    failure|cancelled|timed_out|action_required)
        STATUS="fail"
        REASON="wokwi-ci-action outcome: ${OUTCOME}"
        ;;
    *)
        STATUS="fail"
        REASON="unknown wokwi-ci-action outcome: ${OUTCOME}"
        ;;
esac

{
    echo "== scripts/record_wokwi_ci_result.sh =="
    echo "source: github-actions/wokwi-ci-action"
    echo "outcome: ${OUTCOME}"
    echo "status: ${STATUS}"
    echo "scenario: ${SCENARIO}"
    echo "run: ${RUN_URL}"
} | tee "${WOKWI_LOG}"

write_result_json "${RESULT_JSON}" "wokwi" "${STATUS}" \
    "${REASON}; scenario: ${SCENARIO}; run: ${RUN_URL}" "evidence/latest/wokwi.log" "${EXTRA_JSON}"

echo "== wokwi: ${STATUS} (log: evidence/latest/wokwi.log) =="
