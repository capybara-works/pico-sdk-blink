#!/usr/bin/env bash
# Low-level CTest step.
# Assumes firmware has already been configured/built under build/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"
BUILD_DIR="$(build_dir)"

if [ ! -d "${BUILD_DIR}" ]; then
    echo "FAIL: build directory not found: ${BUILD_DIR} (run scripts/build_firmware.sh first)"
    exit 1
fi

echo "== Run tests (ctest) =="
ctest --test-dir "${BUILD_DIR}" --output-on-failure
