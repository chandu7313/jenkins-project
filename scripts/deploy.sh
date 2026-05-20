#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  Deploy the application container manually (outside Jenkins)
#  Useful for quick deploys, debugging, or first-time setup
#  Run as:   bash scripts/deploy.sh [tag]
# ──────────────────────────────────────────────────────────────

set -euo pipefail

DOCKER_IMAGE="chandu9000/jenkins_devops"
DOCKER_TAG="${1:-latest}"
CONTAINER_NAME="jenkins_devops_container"
APP_PORT="3000"

echo ""
echo "══════════════════════════════════════════════"
echo "  Deploying ${DOCKER_IMAGE}:${DOCKER_TAG}"
echo "══════════════════════════════════════════════"
echo ""

# Pull the latest image
echo "[1/4] Pulling image..."
docker pull "${DOCKER_IMAGE}:${DOCKER_TAG}"

# Stop and remove old container
echo "[2/4] Stopping old container..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Start new container
echo "[3/4] Starting new container..."
docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    -p "${APP_PORT}:3000" \
    -e NODE_ENV=production \
    --memory=512m \
    --cpus=0.5 \
    "${DOCKER_IMAGE}:${DOCKER_TAG}"

# Health check
echo "[4/4] Running health check..."
sleep 5

MAX_RETRIES=6
RETRY_COUNT=0

until curl -sf http://localhost:${APP_PORT}/ > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo "❌ Health check failed after ${MAX_RETRIES} attempts"
        echo "Container logs:"
        docker logs "${CONTAINER_NAME}"
        exit 1
    fi
    echo "  Retry ${RETRY_COUNT}/${MAX_RETRIES} — waiting 5s..."
    sleep 5
done

echo ""
echo "✅ Deployment successful!"
echo ""
docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo ""
