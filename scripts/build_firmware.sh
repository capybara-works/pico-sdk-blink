#!/usr/bin/env bash
# Low-level firmware build step.
# Performs CMake configure + build only. Evidence logging is handled by callers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"

echo "== Configure (cmake) =="
cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}"

echo "== Build =="
cmake --build "${BUILD_DIR}"
