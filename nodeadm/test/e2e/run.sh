#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd $(dirname $0)/../..

NODEADM=$PWD/_bin/nodeadm

if [ ! -f "${NODEADM}" ]; then
  echo >&2 "error: you must build nodeadm (run \`make\`) before you can run the e2e tests!"
  exit 1
fi

printf "🛠️ Building test infra image with containerd v1..."
TEST_IMAGE=$(docker build -q -f test/e2e/infra/Dockerfile .)
echo "done! Test image: $TEST_IMAGE"

FAILED="false"

for CASE_DIR in $(ls -d test/e2e/cases/*); do
  CASE_NAME=$(basename $CASE_DIR)
  if [[ "$CASE_NAME" == containerdv2-* ]]; then
    echo "⏭️ Skip containerd2 test cases $CASE_NAME"
    continue
  fi
  printf "🧪 Testing $CASE_NAME..."
  CONTAINER_ID=$(docker run \
    -d \
    --rm \
    --privileged \
    -v $NODEADM:/usr/local/bin/nodeadm \
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

# test containerdv2
printf "🛠️ Building test infra image with containerd v2..."
TEST_IMAGE2=$(docker build -q -f test/e2e/infra/Dockerfile --build-arg CONTAINERD_VERSION=2.0.5 .)
echo "done! Test image: $TEST_IMAGE2"

for CASE_DIR in $(ls -d test/e2e/cases/containerd*); do
  CASE_NAME=$(basename $CASE_DIR)
  if [[ "$CASE_NAME" == containerdv1-* ]]; then
    echo "⏭️ Skip containerd v1 test cases $CASE_NAME"
    continue
  fi
  printf "🧪 Testing $CASE_NAME..."
  CONTAINER_ID=$(docker run \
    -d \
    --rm \
    --privileged \
    -v $NODEADM:/usr/local/bin/nodeadm \
    -v $PWD/$CASE_DIR:/test-case \
    $TEST_IMAGE2)
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
