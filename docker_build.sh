#!/bin/bash
set -e

# Image name
IMAGE_NAME="pico-sdk-blink-dev"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH."
    exit 1
fi

echo "============================================================"
echo " Building Docker Image: $IMAGE_NAME"
echo "============================================================"

# Build the image using the existing Dockerfile in .devcontainer
# We use the context of the current directory to allow COPY if needed, 
# but the Dockerfile is in .devcontainer
docker build -t $IMAGE_NAME -f .devcontainer/Dockerfile .devcontainer

echo ""
echo "============================================================"
echo " Running Build and Test in Container"
echo "============================================================"

# Run the container
# - --rm: Remove container after exit
# - -v $(pwd):/workspace: Mount current directory to /workspace
# - -w /workspace: Set working directory
# - -u $(id -u):$(id -g): Run as current user to avoid permission issues with generated files
# - --entrypoint /bin/bash: Override entrypoint to run our script
docker run --rm \
    -v "$(pwd):/workspace" \
    -w /workspace \
    -u "$(id -u):$(id -g)" \
    $IMAGE_NAME \
    -c "chmod +x build_and_test.sh && ./build_and_test.sh"

echo ""
echo "============================================================"
echo " Docker Build & Test Complete"
echo "============================================================"
