#!/usr/bin/env bash
# Fetch the latest CI evidence artifact that includes the Wokwi CI result.
#
# Usage:
#   scripts/fetch_ci_evidence.sh              # latest successful run on current branch
#   scripts/fetch_ci_evidence.sh <run_id>     # specific GitHub Actions run
#
# Environment overrides:
#   GH_REPO=owner/repo
#   BRANCH=main
#   WORKFLOW="Build and test (local-equivalent)"
#   CI_EVIDENCE_DIR=/path/to/output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACT_NAME="evidence-with-wokwi"

repo_from_origin() {
    local remote
    remote="$(git -C "${REPO_ROOT}" remote get-url origin 2>/dev/null || true)"
    case "${remote}" in
        https://github.com/*)
            remote="${remote#https://github.com/}"
            remote="${remote%.git}"
            ;;
        git@github.com:*)
            remote="${remote#git@github.com:}"
            remote="${remote%.git}"
            ;;
        *)
            remote=""
            ;;
    esac
    printf '%s\n' "${remote}"
}

if ! command -v gh >/dev/null 2>&1; then
    echo "FAIL: gh is not installed. Install GitHub CLI and authenticate with 'gh auth login'."
    exit 1
fi

REPO="${GH_REPO:-$(repo_from_origin)}"
if [ -z "${REPO}" ]; then
    echo "FAIL: could not infer GitHub repo from origin. Set GH_REPO=owner/repo."
    exit 1
fi

BRANCH="${BRANCH:-$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"
WORKFLOW="${WORKFLOW:-Build and test (local-equivalent)}"
RUN_ID="${1:-}"

if [ -z "${RUN_ID}" ]; then
    echo "== Finding latest successful CI run =="
    echo "repo: ${REPO}"
    echo "branch: ${BRANCH}"
    echo "workflow: ${WORKFLOW}"
    RUN_ID="$(gh run list \
        -R "${REPO}" \
        --workflow "${WORKFLOW}" \
        --branch "${BRANCH}" \
        --status success \
        --limit 1 \
        --json databaseId \
        --jq '.[0].databaseId // ""')"
fi

if [ -z "${RUN_ID}" ]; then
    echo "FAIL: no successful CI run found."
    exit 1
fi

RUN_URL="$(gh run view -R "${REPO}" "${RUN_ID}" --json url --jq '.url')"
OUT_DIR="${CI_EVIDENCE_DIR:-${REPO_ROOT}/artifacts/latest/${ARTIFACT_NAME}}"

mkdir -p "${OUT_DIR}"

echo "== Downloading ${ARTIFACT_NAME} =="
echo "run: ${RUN_URL}"
echo "out: ${OUT_DIR}"
gh run download "${RUN_ID}" -R "${REPO}" --name "${ARTIFACT_NAME}" --dir "${OUT_DIR}"

echo "== CI evidence =="
echo "verification: ${OUT_DIR}/verification.md"
echo "wokwi result: ${OUT_DIR}/wokwi_result.json"

python3 - "${OUT_DIR}/wokwi_result.json" <<'PYEOF'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
if not path.exists():
    print(f"wokwi status: missing ({path})")
    sys.exit(1)

with path.open() as f:
    result = json.load(f)

status = result.get("status", "unknown")
reason = result.get("reason", "")
print(f"wokwi status: {status}")
if reason:
    print(f"wokwi reason: {reason}")
PYEOF
