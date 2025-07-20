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

printf "🛠️ Building test infra image..."
TEST_IMAGE=$(docker build -q -f test/e2e/infra/Dockerfile .)
echo "done! Test image: $TEST_IMAGE"

FAILED="false"

CASE_PREFIX=${1:-}

for CASE_DIR in $(ls -d test/e2e/cases/${CASE_PREFIX}*); do
  CASE_NAME=$(basename $CASE_DIR)
  printf "🧪 Testing $CASE_NAME..."
  CONTAINER_ID=$(docker run \
    -d \
    --rm \
    --privileged \
    $MOUNT_FLAGS \
    -v $PWD/$CASE_DIR:/test-case \
    $TEST_IMAGE)
  LOG_FILE=$(mktemp)
  if docker exec $CONTAINER_ID bash -c "cd /test-case && ./run.sh" > $LOG_FILE 2>&1; then
    echo "passed! ✅"
  else
    echo "failed! ❌"
    cat $LOG_FILE
    FAILED="true"
  fi
  docker kill $CONTAINER_ID > /dev/null 2>&1
done

if [ "${FAILED}" = "true" ]; then
  echo "❌ Some tests failed!"
  exit 1
else
  echo "✅ All tests passed!"
  exit 0
fi
