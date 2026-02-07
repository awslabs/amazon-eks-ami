#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

cd "$(dirname $0)/../.."

declare -A MOUNT_TARGETS=(
  ['nodeadm']=$PWD/_bin/nodeadm
  ['nodeadm-internal']=$PWD/_bin/nodeadm-internal
)

# build image
printf "🛠️ Building test infra image with containerd v1..."
CONTAINERD_V1_IMAGE=$(docker build -q -f test/e2e/infra/Dockerfile --build-arg CONTAINERD_VERSION=1.7.* .)
echo "done! Test image with containerd v1: $CONTAINERD_V1_IMAGE"

printf "🛠️ Building test infra image with containerd v2..."
CONTAINERD_V2_IMAGE=$(docker build -q -f test/e2e/infra/Dockerfile --build-arg CONTAINERD_VERSION=2.0.5 .)
echo "done! Test image with containerd v2: $CONTAINERD_V2_IMAGE"

FAILED="false"

function runTest() {
  local case_dir=$1
  local image=$2

  local case_name
  case_name=$(basename "$case_dir")

  if [ $image = "$CONTAINERD_V1_IMAGE" ]; then
    echo -n "🧪 Testing $case_name with containerd v1 image..."
  else
    echo -n "🧪 Testing $case_name with containerd v2 image..."
  fi

  local workdir=/test-case
  local docker_args=(
    --detach
    --rm
    --privileged
    # NOTE: we force the mac address of the container to be the one from the
    # ec2-metadata-mock to make expectations match.
    --mac-address "$(jq -r '.metadata.values.mac' $case_dir/../../infra/aemm-default-config.json)"
    --workdir "$workdir"
    --volume "$(pwd)/$case_dir:$workdir"
  )

  for binary in "${!MOUNT_TARGETS[@]}"; do
    if [ ! -f "${MOUNT_TARGETS[$binary]}" ]; then
      echo >&2 "error: you must build nodeadm (run \`make\`) before you can run the e2e tests!"
      exit 1
    fi
    docker_args+=(--volume "${MOUNT_TARGETS[$binary]}:/usr/local/bin/$binary")
  done

  local containerd_id
  containerd_id=$(docker run "${docker_args[@]}" "$image")

  local logfile
  logfile=$(mktemp)

  local start_time
  start_time=$(date +%s)
  if docker exec "$containerd_id" ./run.sh > "$logfile" 2>&1; then
    local elapsed
    elapsed=$(($(date +%s) - start_time))
    echo "passed! ✅ (${elapsed}s)"
  else
    local elapsed
    elapsed=$(($(date +%s) - start_time))
    echo "failed! ❌ (${elapsed}s)"
    cat "$logfile"
    FAILED="true"
  fi

  # killing a container should not take more than 5 seconds.
  timeout 5 docker kill "$containerd_id" > /dev/null 2>&1
}

# Run tests
CASE_PREFIX=${1:-}
for CASE_DIR in test/e2e/cases/${CASE_PREFIX}*; do
  CASE_NAME=$(basename "$CASE_DIR")
  if [[ "$CASE_NAME" == containerdv2-* ]]; then
    runTest "$CASE_DIR" "$CONTAINERD_V2_IMAGE"
    continue
  elif [[ "$CASE_NAME" == containerd-* ]]; then
    runTest "$CASE_DIR" "$CONTAINERD_V2_IMAGE"
  fi
  runTest "$CASE_DIR" "$CONTAINERD_V1_IMAGE"
done

if [ "$FAILED" = "true" ]; then
  echo "❌ Some tests failed!"
  exit 1
else
  echo "✅ All tests passed!"
  exit 0
fi
