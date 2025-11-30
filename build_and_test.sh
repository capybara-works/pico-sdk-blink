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
