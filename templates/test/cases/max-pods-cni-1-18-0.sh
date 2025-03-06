#!/usr/bin/env bash
set -euo pipefail

echo "-> Should calc max-pods successfully for c6in.32xlarge VPC CNI 1.18.0"
exit_code=0
out=$(/etc/eks/max-pods-calculator.sh \
  --instance-type c6in.32xlarge \
  --cni-version 1.18.0 \
  --show-max-allowed || exit_code=$?)
echo $out

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi
expected_max_pods="394"
actual_max_pods=$(grep -o '[0-9]\+' <<< ${out})
if [[ ${actual_max_pods} -ne ${expected_max_pods} ]]; then
  echo "❌ Test Failed: expected max-pods for c6in.32xlarge w/ CNI 1.18.5 to be '${expected_max_pods}', but got '${actual_max_pods}'"
  exit 1
fi
