#!/usr/bin/env bash
set -euo pipefail

echo "--> Should be able to set allowedUnsafeSysctls"
exit_code=0
export KUBELET_VERSION=v1.27.0-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --allowed-unsafe-sysctls 'kernel.msg*,net.core.somaxconn' \
  test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

echo '["kernel.msg*","net.core.somaxconn"]' | jq . > expected_allowed_unsafe_sysctls.json
jq '.allowedUnsafeSysctls' /etc/kubernetes/kubelet/kubelet-config.json > actual_allowed_unsafe_sysctls.json

diffResult=$(diff expected_allowed_unsafe_sysctls.json actual_allowed_unsafe_sysctls.json)
rm expected_allowed_unsafe_sysctls.json actual_allowed_unsafe_sysctls.json
if [ -n "$diffResult" ]; then
  echo "❌ Test Failed."
  echo "$diffResult"
  exit 1
fi
