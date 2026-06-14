#!/bin/bash
set -euo pipefail

LOCAL_IMAGE_NAME="${PICO_DOCKER_IMAGE_NAME:-pico-sdk-blink-dev}"
PREBUILT_IMAGE="${PICO_DEVCONTAINER_IMAGE:-ghcr.io/capybara-works/pico-sdk-blink/devcontainer:main}"
FORCE_BUILD="${PICO_DOCKER_FORCE_BUILD:-0}"

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
    docker build -t "$LOCAL_IMAGE_NAME" -f .devcontainer/Dockerfile .devcontainer
}

if [[ "$FORCE_BUILD" == "1" ]]; then
    echo "PICO_DOCKER_FORCE_BUILD=1; skipping prebuilt image pull."
    build_image
else
    echo "Trying prebuilt image: $PREBUILT_IMAGE"
    if docker pull "$PREBUILT_IMAGE"; then
        docker tag "$PREBUILT_IMAGE" "$LOCAL_IMAGE_NAME"
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
# - --entrypoint /bin/bash: Override entrypoint to run our script
docker run --rm \
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
