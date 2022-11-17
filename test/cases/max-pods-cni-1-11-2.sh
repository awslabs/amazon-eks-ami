#!/usr/bin/env bash
set -euo pipefail

echo "-> Should calc max-pods successfully for m5.8xlarge VPC CNI 1.11.2"
exit_code=0
out=$(/etc/eks/max-pods-calculator.sh \
  --instance-type m5.8xlarge \
  --cni-version 1.11.2 || exit_code=$?)
echo $out

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi
expected_max_pods="234"
actual_max_pods=$(grep -o '[0-9]\+' <<< ${out})
if [[ ${actual_max_pods} -ne ${expected_max_pods} ]]; then
  echo "❌ Test Failed: expected max-pods for m4.xlarge w/ CNI 1.11.2 to be '${expected_max_pods}', but got '${actual_max_pods}'"
  exit 1
fi
