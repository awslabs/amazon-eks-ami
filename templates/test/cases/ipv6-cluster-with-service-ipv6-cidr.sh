#!/usr/bin/env bash
set -euo pipefail

echo "-> Should return IPv6 DNS cluster IP when --service-ipv6-cidr set"
exit_code=0
TEMP_DIR=$(mktemp -d)
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --ip-family ipv6 \
  --service-ipv6-cidr fe80::1 \
  ipv6-cluster || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

expected_cluster_dns="fe80::1a"
actual_cluster_dns=$(jq -r '.clusterDNS[0]' < /etc/kubernetes/kubelet/kubelet-config.json)
if [[ ${actual_cluster_dns} != "${expected_cluster_dns}" ]]; then
  echo "❌ Test Failed: expected clusterDNS IP '${expected_cluster_dns}' but got '${actual_cluster_dns}'"
  exit 1
fi
