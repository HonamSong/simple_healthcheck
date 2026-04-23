#!/usr/bin/env bash
#
# Build & Push script for GCP Artifact Registry
# Usage: ./build-and-push.sh
#
set -euo pipefail

# ========= 설정 =========
REGISTRY="asia-northeast3-docker.pkg.dev"
PROJECT_ID="portal-dev-490501"
REPOSITORY="infra"
IMAGE_NAME="shutdown_health"
TAG="latest"
PLATFORM="linux/amd64"   # Ubuntu x86_64 타겟
DOCKERFILE_PATH="."

IMAGE_URI="${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${TAG}"

# ========= 로그 함수 =========
log()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# ========= 사전 점검 =========
log "Pre-flight checks..."

command -v docker  >/dev/null || { err "docker not found";  exit 1; }
command -v gcloud  >/dev/null || { err "gcloud not found";  exit 1; }

# gcloud 로그인 상태 확인
if ! gcloud auth print-access-token >/dev/null 2>&1; then
  err "gcloud not authenticated. Run: gcloud auth login"
  exit 1
fi

# Docker 데몬 동작 확인
if ! docker info >/dev/null 2>&1; then
  err "Docker daemon is not running."
  exit 1
fi

# buildx 빌더 확인 및 준비
if ! docker buildx inspect multiarch >/dev/null 2>&1; then
  log "Creating buildx builder 'multiarch'..."
  docker buildx create --name multiarch --use >/dev/null
else
  docker buildx use multiarch >/dev/null
fi

# ========= 빌드 & 푸시 =========
log "Target image: ${IMAGE_URI}"
log "Platform    : ${PLATFORM}"
log "Building and pushing..."

docker buildx build \
  --platform "${PLATFORM}" \
  -t "${IMAGE_URI}" \
  --push \
  "${DOCKERFILE_PATH}"

# ========= 결과 확인 =========
log "Verifying pushed image in Artifact Registry..."
gcloud artifacts docker images describe "${IMAGE_URI}" \
  --format="value(image_summary.digest)" \
  || warn "Could not verify image (check permissions)."

log "Done. Pulled anywhere with:"
echo "    docker pull ${IMAGE_URI}"
