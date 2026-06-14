#!/bin/bash
set -euo pipefail

LOCAL_IMAGE_NAME="${PICO_DOCKER_IMAGE_NAME:-pico-sdk-blink-dev}"
PREBUILT_IMAGE="${PICO_DEVCONTAINER_IMAGE:-ghcr.io/capybara-works/pico-sdk-blink/devcontainer:main}"
FORCE_BUILD="${PICO_DOCKER_FORCE_BUILD:-0}"
DOCKER_PLATFORM="${PICO_DOCKER_PLATFORM:-linux/amd64}"
DEVCONTAINER_PATHS=(.devcontainer .github/workflows/devcontainer-image.yml)

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    exit 1
fi

echo "============================================================"
echo " Preparing Docker Image: $LOCAL_IMAGE_NAME"
echo "============================================================"

build_image() {
    echo "Building local image from .devcontainer/Dockerfile..."
    docker build --platform "$DOCKER_PLATFORM" -t "$LOCAL_IMAGE_NAME" -f .devcontainer/Dockerfile .devcontainer
}

devcontainer_has_local_changes() {
    [ -n "$(git status --porcelain -- "${DEVCONTAINER_PATHS[@]}" 2>/dev/null || true)" ]
}

prebuilt_has_current_devcontainer() {
    local image_rev head_rev
    image_rev="$(docker image inspect "$PREBUILT_IMAGE" \
        --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' 2>/dev/null || true)"
    head_rev="$(git rev-parse HEAD 2>/dev/null || true)"

    if [[ -z "$head_rev" || "$image_rev" == "$head_rev" ]]; then
        return 0
    fi
    if [[ -z "$image_rev" ]]; then
        echo "Prebuilt image revision label is missing; building local image."
        return 1
    fi
    if ! git cat-file -e "${image_rev}^{commit}" 2>/dev/null; then
        echo "Prebuilt image revision cannot be checked locally; building local image."
        return 1
    fi
    git diff --quiet "$image_rev" "$head_rev" -- "${DEVCONTAINER_PATHS[@]}"
}

if [[ "$FORCE_BUILD" == "1" ]]; then
    echo "PICO_DOCKER_FORCE_BUILD=1; skipping prebuilt image pull."
    build_image
elif devcontainer_has_local_changes; then
    echo "Local DevContainer files have uncommitted changes; building local image."
    build_image
else
    echo "Trying prebuilt image: $PREBUILT_IMAGE ($DOCKER_PLATFORM)"
    if docker pull --platform "$DOCKER_PLATFORM" "$PREBUILT_IMAGE"; then
        if prebuilt_has_current_devcontainer; then
            docker tag "$PREBUILT_IMAGE" "$LOCAL_IMAGE_NAME"
        else
            echo "Prebuilt image predates DevContainer changes in this branch; building local image."
            build_image
        fi
    else
        echo "Prebuilt image is unavailable; falling back to a local build."
        build_image
    fi
fi

echo ""
echo "============================================================"
echo " Running Build and Test in Container"
echo "============================================================"

DOCKER_ENV_ARGS=()
if [[ -n "${WOKWI_CLI_TOKEN:-}" ]]; then
    DOCKER_ENV_ARGS+=(-e WOKWI_CLI_TOKEN)
fi

# Run the container
# - --rm: Remove container after exit
# - -v $(pwd):/workspace: Mount current directory to /workspace
# - -w /workspace: Set working directory
# - -u $(id -u):$(id -g): Run as current user to avoid permission issues with generated files
# - -e WOKWI_CLI_TOKEN: Pass through local Wokwi token when present
# - --platform: Use the published DevContainer image architecture by default
# - --entrypoint /bin/bash: Override entrypoint to run our script
docker run --rm \
    --platform "$DOCKER_PLATFORM" \
    -v "$(pwd):/workspace" \
    -w /workspace \
    -u "$(id -u):$(id -g)" \
    "${DOCKER_ENV_ARGS[@]}" \
    --entrypoint /bin/bash \
    "$LOCAL_IMAGE_NAME" \
    -lc "chmod +x scripts/*.sh && PICO_BUILD_DIR=/workspace/build-docker scripts/build.sh"

echo ""
echo "============================================================"
echo " Docker Build & Test Complete"
echo "============================================================"
