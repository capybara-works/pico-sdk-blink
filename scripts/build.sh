#!/usr/bin/env bash
# Build entry point.
# Runs firmware build, CTest, and optional Wokwi scenario test, recording each
# result separately under evidence/latest/.
#
# Outputs:
#   evidence/latest/build.log
#   evidence/latest/build_result.json
#   evidence/latest/ctest.log
#   evidence/latest/ctest_result.json
#   evidence/latest/wokwi.log
#   evidence/latest/wokwi_result.json
# Exit code: 0 = pass, 1 = fail

set -u -o pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

BUILD_LOG="${EVIDENCE_DIR}/build.log"
BUILD_RESULT_JSON="${EVIDENCE_DIR}/build_result.json"
CTEST_LOG="${EVIDENCE_DIR}/ctest.log"
CTEST_RESULT_JSON="${EVIDENCE_DIR}/ctest_result.json"
WOKWI_LOG="${EVIDENCE_DIR}/wokwi.log"
WOKWI_RESULT_JSON="${EVIDENCE_DIR}/wokwi_result.json"

run_required_step() {
    local step="$1"
    local log_path="$2"
    local result_json="$3"
    local log_rel="evidence/latest/$(basename "${log_path}")"
    local extra_json=""
    shift 3

    echo "== scripts/build.sh: ${step} =="
    if "$@" 2>&1 | tee "${log_path}"; then
        case "${step}" in
            build)
                extra_json="$(artifact_metadata_json blink.elf blink.uf2 blink.bin)"
                ;;
            wokwi)
                extra_json="$(artifact_metadata_json blink.elf blink.uf2)"
                ;;
        esac
        write_result_json "${result_json}" "${step}" "pass" "" "${log_rel}" "${extra_json}"
        echo "== ${step}: pass (log: ${log_rel}) =="
        return 0
    fi

    local rc=$?
    case "${step}" in
        build)
            extra_json="$(artifact_metadata_json blink.elf blink.uf2 blink.bin)"
            ;;
        wokwi)
            extra_json="$(artifact_metadata_json blink.elf blink.uf2)"
            ;;
    esac
    write_result_json "${result_json}" "${step}" "fail" \
        "exit code ${rc}; see ${log_rel}" "${log_rel}" "${extra_json}"
    echo "== ${step}: fail (log: ${log_rel}) =="
    return 1
}

skip_wokwi_step() {
    local reason="$1"
    {
        echo "== Run Wokwi Test (Optional) =="
        echo "SKIP: ${reason}"
        echo "To run Wokwi tests locally, set WOKWI_CLI_TOKEN and install wokwi-cli."
    } | tee "${WOKWI_LOG}"
    write_result_json "${WOKWI_RESULT_JSON}" "wokwi" "skip" \
        "${reason}" "evidence/latest/wokwi.log" "$(artifact_metadata_json blink.elf blink.uf2)"
    echo "== wokwi: skip (log: evidence/latest/wokwi.log) =="
}

run_wokwi_step() {
    if [ -z "${WOKWI_CLI_TOKEN:-}" ]; then
        skip_wokwi_step "WOKWI_CLI_TOKEN is not set."
        return 0
    fi

    if ! command -v wokwi-cli >/dev/null 2>&1; then
        skip_wokwi_step "wokwi-cli not found."
        return 0
    fi

    run_required_step "wokwi" "${WOKWI_LOG}" "${WOKWI_RESULT_JSON}" \
        "${REPO_ROOT}/scripts/test_wokwi.sh"
}

echo "== scripts/build.sh: running build_firmware + ctest + optional Wokwi =="

run_required_step "build" "${BUILD_LOG}" "${BUILD_RESULT_JSON}" \
    "${REPO_ROOT}/scripts/build_firmware.sh" || exit 1

run_required_step "ctest" "${CTEST_LOG}" "${CTEST_RESULT_JSON}" \
    "${REPO_ROOT}/scripts/test_ctest.sh" || exit 1

run_wokwi_step || exit 1

echo "== build pipeline: pass =="
