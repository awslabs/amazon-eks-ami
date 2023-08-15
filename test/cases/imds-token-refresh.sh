#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

echo "--> Should refresh IMDS token on configured interval"
exit_code=0
TOKEN_DIR=/tmp/imds-tokens/$(whoami)
TTL=5
export IMDS_TOKEN_TTL_SECONDS=$TTL
export IMDS_DEBUG=true
imds /latest/meta-data/instance-id || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
elif [[ $(ls $TOKEN_DIR | wc -l) -ne 1 ]]; then
  echo "❌ Test Failed: expected one token to be present after first IMDS call but got '$(ls $TOKEN_DIR)'"
  exit 1
fi

imds /latest/meta-data/instance-id || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
elif [[ $(ls $TOKEN_DIR | wc -l) -ne 1 ]]; then
  echo "❌ Test Failed: expected one token to be present after second IMDS call but got '$(ls $TOKEN_DIR)'"
  exit 1
fi

sleep $(($TTL + 1))

imds /latest/meta-data/instance-id || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
elif [[ $(ls $TOKEN_DIR | wc -l) -ne 2 ]]; then
  echo "❌ Test Failed: expected two tokens to be present after third IMDS call but got '$(ls $TOKEN_DIR)'"
  exit 1
fi

sleep $(($TTL + 1))

# both tokens are now expired, but only one should be garbage-collected with a window of $TTL

IMDS_MAX_TOKEN_TTL_SECONDS=$TTL imds /latest/meta-data/instance-id || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
elif [[ $(ls $TOKEN_DIR | wc -l) -ne 2 ]]; then
  echo "❌ Test Failed: expected two tokens to be present after first garbage-collection but got '$(ls $TOKEN_DIR)'"
  exit 1
fi

# the other expired token should be removed with a window of 0

IMDS_MAX_TOKEN_TTL_SECONDS=0 imds /latest/meta-data/instance-id || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
elif [[ $(ls $TOKEN_DIR | wc -l) -ne 1 ]]; then
  echo "❌ Test Failed: expected one token to be present after second garbage-collection but got '$(ls $TOKEN_DIR)'"
  exit 1
fi
