#!/usr/bin/env bash
#
# Build & Push script for GCP Artifact Registry
# Usage: ./build_push.sh
#
# Configuration is loaded from a local .env file (not committed).
# Copy .env.example to .env and fill in your values before running.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ========= 환경변수 로드 (.env) =========
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/.env"
  set +a
fi

# ========= 필수 변수 검증 =========
: "${REGISTRY:?REGISTRY is required (e.g. <REGION>-docker.pkg.dev). Set it in .env.}"
: "${PROJECT_ID:?PROJECT_ID is required. Set it in .env.}"
: "${REPOSITORY:?REPOSITORY is required. Set it in .env.}"
: "${IMAGE_NAME:?IMAGE_NAME is required. Set it in .env.}"
TAG="${TAG:-latest}"
PLATFORM="${PLATFORM:-linux/amd64}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-${SCRIPT_DIR}}"

IMAGE_URI="${REGISTRY}/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${TAG}"

# ========= 로그 함수 =========
log()  { echo -e "\033[1;32m[INFO]\033[0m  $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
err()  { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }

# ========= 사전 점검 =========
log "Pre-flight checks..."

command -v docker  >/dev/null || { err "docker not found";  exit 1; }
command -v gcloud  >/dev/null || { err "gcloud not found";  exit 1; }

if ! gcloud auth print-access-token >/dev/null 2>&1; then
  err "gcloud not authenticated. Run: gcloud auth login"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  err "Docker daemon is not running."
  exit 1
fi

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
