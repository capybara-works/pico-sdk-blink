#!/usr/bin/env bash
# Compatibility wrapper. Prefer scripts/build.sh for new automation because it
# records evidence under evidence/latest/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== build_and_test.sh: compatibility wrapper; delegating to scripts/build.sh =="
"${SCRIPT_DIR}/scripts/build.sh"
