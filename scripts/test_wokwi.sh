#!/usr/bin/env bash
# Low-level optional Wokwi scenario test.
# Exits 0 when Wokwi is intentionally unavailable, preserving local ergonomics.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "== Run Wokwi Test (Optional) =="
if [ -z "${WOKWI_CLI_TOKEN:-}" ]; then
    echo "SKIP: WOKWI_CLI_TOKEN is not set."
    echo "To run Wokwi tests locally, set WOKWI_CLI_TOKEN and install @wokwi/cli."
    exit 0
fi

if command -v wokwi-cli >/dev/null 2>&1; then
    WOKWI_CMD=(wokwi-cli)
elif command -v npx >/dev/null 2>&1; then
    WOKWI_CMD=(npx -y @wokwi/cli)
else
    echo "SKIP: wokwi-cli or npx not found."
    echo "Please install Node.js to run Wokwi tests locally."
    exit 0
fi

echo "Running Wokwi test with ${WOKWI_CMD[*]}..."
"${WOKWI_CMD[@]}" "${REPO_ROOT}" --scenario "${REPO_ROOT}/blink.test.yaml" --timeout 5000
