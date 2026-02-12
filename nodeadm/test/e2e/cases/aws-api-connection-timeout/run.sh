#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

wait::dbus-ready

# IMDS should be available, but the AWS API should be a void
mock::imds
mock::connection-timeout-server 5000
mock::kubelet 1.29.0

DEFAULT_MAX_ATTEMPTS=3
CONNECTION_TIMEOUT=30

# This must be different from either our default of 30 or the aws default of 3.
MAX_ATTEMPTS_VALUE=1

echo "testing with MAX_ATTEMPTS=${MAX_ATTEMPTS_VALUE}"
START=$(date +%s)
AWS_MAX_ATTEMPTS=${MAX_ATTEMPTS_VALUE} nodeadm init --development --skip run --config-source file://config.yaml || true
END=$(date +%s)
SECONDS_ELAPSED=$((END - START))
LOWER_BOUND=$((MAX_ATTEMPTS_VALUE * CONNECTION_TIMEOUT))
UPPER_BOUND=$((LOWER_BOUND + 5))
echo "MAX_ATTEMPTS=${MAX_ATTEMPTS_VALUE} SECONDS_ELAPSED=${SECONDS_ELAPSED}, LOWER_BOUND=${LOWER_BOUND}, UPPER_BOUND=${UPPER_BOUND}"
if ! ((SECONDS_ELAPSED >= LOWER_BOUND && SECONDS_ELAPSED <= UPPER_BOUND)); then
  echo "The observed AWS SDK retry behavior did not fall within the expected range!"
  exit 1
fi

# now, we need to make sure that if no override is specified,
# we use our increased number of attempts instead of the default

nodeadm init --development --skip run --config-source file://config.yaml &
NODEADM_PID=$!

sleep $((CONNECTION_TIMEOUT * (DEFAULT_MAX_ATTEMPTS + 1)))

if ! kill -0 "$NODEADM_PID" &> /dev/null; then
  echo "nodeadm was not still running after waiting out the default retry period; this means our retry config is not working as intended!"
  exit 1
fi
