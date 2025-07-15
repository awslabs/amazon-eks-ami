#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd $(dirname $0)/../..

declare MOUNT_FLAGS=""
declare -A MOUNT_TARGETS=(
  ['nodeadm']=$PWD/_bin/nodeadm
  ['nodeadm-internal']=$PWD/_bin/nodeadm-internal
)

for binary in "${!MOUNT_TARGETS[@]}"; do
  if [ ! -f "${MOUNT_TARGETS[$binary]}" ]; then
    echo >&2 "error: you must build nodeadm (run \`make\`) before you can run the e2e tests!"
    exit 1
  fi
  MOUNT_FLAGS+=" -v ${MOUNT_TARGETS[$binary]}:/usr/local/bin/$binary"
done

# build image
printf "🛠️ Building test infra image with containerd v1..."
CONTAINERD_V1_IMAGE=$(docker build -q -f test/e2e/infra/Dockerfile --build-arg CONTAINERD_VERSION=1.7.* .)
echo "done! Test image with containerd v1: $CONTAINERD_V1_IMAGE"

printf "🛠️ Building test infra image with containerd v2..."
CONTAINERD_V2_IMAGE=$(docker build -q -f test/e2e/infra/Dockerfile --build-arg CONTAINERD_VERSION=2.0.5 .)
echo "done! Test image with containerd v2: $CONTAINERD_V2_IMAGE"

FAILED="false"

function runTest() {
  local case_name=$1
  local image=$2
  if [[ $image == $CONTAINERD_V1_IMAGE ]]; then
    printf "🧪 Testing %s with containerd v1 image..." "$case_name"
  else
    printf "🧪 Testing %s with containerd v2 image..." "$case_name"
  fi

  CONTAINER_ID=$(docker run \
    -d \
    --rm \
    --privileged \
    $MOUNT_FLAGS \
    -v "$PWD/$CASE_DIR":/test-case \
    "$image")

  LOG_FILE=$(mktemp)
  if docker exec "$CONTAINER_ID" bash -c "cd /test-case && ./run.sh" > "$LOG_FILE" 2>&1; then
    echo "passed! ✅"
  else
    echo "failed! ❌"
    cat "$LOG_FILE"
    FAILED="true"
  fi
  docker kill "$CONTAINER_ID" > /dev/null 2>&1
}

# Run tests
CASE_PREFIX=${1:-}
for CASE_DIR in $(ls -d test/e2e/cases/${CASE_PREFIX}*); do
  CASE_NAME=$(basename "$CASE_DIR")
  if [[ "$CASE_NAME" == containerdv2-* ]]; then
    runTest "$CASE_NAME" "$CONTAINERD_V2_IMAGE"
    continue
  elif [[ "$CASE_NAME" == containerd-* ]]; then
    runTest "$CASE_NAME" "$CONTAINERD_V2_IMAGE"
  fi
  runTest "$CASE_NAME" "$CONTAINERD_V1_IMAGE"
done

if [ "$FAILED" = "true" ]; then
  echo "❌ Some tests failed!"
  exit 1
else
  echo "✅ All tests passed!"
  exit 0
fi
