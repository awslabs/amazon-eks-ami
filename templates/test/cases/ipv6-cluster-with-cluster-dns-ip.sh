#!/usr/bin/env bash
set -euo pipefail

echo "-> Should return IPv6 DNS Cluster IP when --dns-cluster-ip set"
exit_code=0
expected_cluster_dns="fe80::2a"
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --ip-family ipv6 \
  --dns-cluster-ip "${expected_cluster_dns}" \
  ipv6-cluster || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

actual_cluster_dns=$(jq -r '.clusterDNS[0]' < /etc/kubernetes/kubelet/kubelet-config.json)
if [[ ${actual_cluster_dns} != "${expected_cluster_dns}" ]]; then
  echo "❌ Test Failed: expected clusterDNS IP '${expected_cluster_dns}' but got '${actual_cluster_dns}'"
  exit 1
fi
