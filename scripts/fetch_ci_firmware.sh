#!/usr/bin/env bash
# Fetch the CI firmware artifact for Docker/CI payload hash comparison.
#
# Usage:
#   scripts/fetch_ci_firmware.sh              # latest successful run on current branch
#   scripts/fetch_ci_firmware.sh <run_id>     # specific GitHub Actions run
#
# Environment overrides:
#   GH_REPO=owner/repo
#   BRANCH=main
#   WORKFLOW="Build and test (local-equivalent)"
#   CI_FIRMWARE_DIR=/path/to/output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACT_NAME="firmware"

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

hash_file() {
    local file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "${file}"
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${file}"
    else
        echo "sha256 unavailable: ${file}"
    fi
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
if [ -n "${CI_FIRMWARE_DIR:-}" ]; then
    OUT_DIR="${CI_FIRMWARE_DIR}"
else
    OUT_DIR="${REPO_ROOT}/artifacts/latest/${ARTIFACT_NAME}/${RUN_ID}"
fi

mkdir -p "${OUT_DIR}"

echo "== Downloading ${ARTIFACT_NAME} =="
echo "run: ${RUN_URL}"
echo "out: ${OUT_DIR}"
if [ -f "${OUT_DIR}/blink.uf2" ] && [ -f "${OUT_DIR}/blink.bin" ]; then
    echo "artifact already present; using existing files"
else
    gh run download "${RUN_ID}" -R "${REPO}" --name "${ARTIFACT_NAME}" --dir "${OUT_DIR}"
fi

missing=0
for required in blink.uf2 blink.bin; do
    if [ ! -f "${OUT_DIR}/${required}" ]; then
        echo "FAIL: missing ${OUT_DIR}/${required}"
        missing=1
    fi
done
if [ "${missing}" -ne 0 ]; then
    exit 1
fi

echo "== CI firmware =="
while IFS= read -r artifact; do
    hash_file "${artifact}"
done < <(find "${OUT_DIR}" -maxdepth 1 -type f -name 'blink.*' | sort)
