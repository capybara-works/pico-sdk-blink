#!/usr/bin/env bash
# set -e: 途中でエラーが出たらそこで止める
set -e

# このスクリプト自身が置かれているディレクトリを基準にする
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ビルドディレクトリのパス
BUILD_DIR="${SCRIPT_DIR}/build"

echo "== Configure (cmake) =="
cmake -S "${SCRIPT_DIR}" -B "${BUILD_DIR}"

echo "== Build =="
cmake --build "${BUILD_DIR}"


echo "== Run tests (ctest) =="
cd "${BUILD_DIR}"
ctest

echo "== Run Wokwi Test (Optional) =="
# Check if WOKWI_CLI_TOKEN is set
if [ -z "$WOKWI_CLI_TOKEN" ]; then
    echo "SKIP: WOKWI_CLI_TOKEN is not set."
    echo "To run Wokwi tests locally, set WOKWI_CLI_TOKEN and install @wokwi/cli."
else
    # Check if wokwi-cli is installed (globally or via npx)
    if command -v wokwi-cli &> /dev/null; then
        WOKWI_CMD="wokwi-cli"
    elif command -v npx &> /dev/null; then
        WOKWI_CMD="npx -y @wokwi/cli"
    else
        echo "SKIP: wokwi-cli or npx not found."
        echo "Please install Node.js to run Wokwi tests locally."
        exit 0
    fi

    echo "Running Wokwi test with ${WOKWI_CMD}..."
    cd "${SCRIPT_DIR}"
    $WOKWI_CMD "${SCRIPT_DIR}" --scenario "${SCRIPT_DIR}/blink.test.yaml" --timeout 5000
fi
