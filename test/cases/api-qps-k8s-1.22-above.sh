#!/usr/bin/env bash
set -euo pipefail

echo "--> Should increase API server QPS for K8s 1.22+"
exit_code=0
export KUBELET_VERSION=v1.22.0-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

expected_api_qps="10"
expected_api_burst="20"

actual_api_qps=$(jq -r '.kubeAPIQPS' < /etc/kubernetes/kubelet/kubelet-config.json)
actual_api_burst=$(jq -r '.kubeAPIBurst' < /etc/kubernetes/kubelet/kubelet-config.json)
if [[ ${actual_api_qps} != ${expected_api_qps} ]]; then
  echo "❌ Test Failed: expected kubeAPIQPS = '${expected_api_qps}' but got '${actual_api_qps}'"
  exit 1
fi

if [[ ${actual_api_burst} != ${expected_api_burst} ]]; then
  echo "❌ Test Failed: expected kubeAPIBurst = '${expected_api_burst}' but got '${actual_api_burst}'"
  exit 1
fi
