#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

echo "--> Should fetch PrivateDnsName correctly"
EXPECTED_PRIVATE_DNS_NAME="ip-10-0-0-157.us-east-2.compute.internal"
PRIVATE_DNS_NAME=$(private-dns-name)
if [ ! "$PRIVATE_DNS_NAME" = "$EXPECTED_PRIVATE_DNS_NAME" ]; then
  echo "❌ Test Failed: expected private-dns-name=$EXPECTED_PRIVATE_DNS_NAME but got '${PRIVATE_DNS_NAME}'"
  exit 1
fi

echo "--> Should try to fetch PrivateDnsName until timeout is reached"
export PRIVATE_DNS_NAME_ATTEMPT_INTERVAL=3
export PRIVATE_DNS_NAME_MAX_ATTEMPTS=2
export AWS_MOCK_FAIL=true
START_TIME=$(date '+%s')
EXIT_CODE=0
private-dns-name || EXIT_CODE=$?
STOP_TIME=$(date '+%s')
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code"
  exit 1
fi
ELAPSED_TIME=$((STOP_TIME - START_TIME))
if [[ "$ELAPSED_TIME" -lt 6 ]]; then
  echo "❌ Test Failed: expected 6 seconds to elapse, but got: $ELAPSED_TIME"
  exit 1
fi
