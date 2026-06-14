#!/usr/bin/env bash
# Low-level firmware build step.
# Performs CMake configure + build only. Evidence logging is handled by callers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/common.sh"
BUILD_DIR="$(build_dir)"

echo "== Configure (cmake) =="
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}"

echo "== Build =="
cmake --build "${BUILD_DIR}"
