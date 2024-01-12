#!/usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

echo "--> Should fetch imds details correctly"
EXPECTED_INSTANCE_ID="i-1234567890abcdef0"
EXPECTED_AVAILABILITY_ZONE="us-east-1a"
EXPECTED_PROVIDER_ID="aws:///$EXPECTED_AVAILABILITY_ZONE/$EXPECTED_INSTANCE_ID"
PROVIDER_ID=$(provider-id)
if [ ! "$PROVIDER_ID" = "$EXPECTED_PROVIDER_ID" ]; then
  echo "❌ Test Failed: expected provider-id=$EXPECTED_PROVIDER_ID but got '${PROVIDER_ID}'"
  exit 1
fi

echo "--> Should fail when imds is unreachable"
echo '#!/usr/bin/sh
exit 1' > $(which imds)
EXIT_CODE=0
provider-id || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code"
  exit 1
fi
