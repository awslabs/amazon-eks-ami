#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

export IMDS_DEBUG=true

echo "--> Should succeed for known API"
EXIT_CODE=0
imds /latest/meta-data/instance-id || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got: $EXIT_CODE"
  exit 1
fi

echo "--> Should fail for unknown API"
EXIT_CODE=0
imds /foo || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code"
  exit 1
fi

echo "--> Should fail for invalid endpoint"
EXIT_CODE=0
export IMDS_ENDPOINT="127.0.0.0:1234"
imds /latest/meta-data/instance-id || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code"
  exit 1
fi
