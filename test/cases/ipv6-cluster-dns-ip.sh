#!/usr/bin/env bash
set -euo pipefail

echo "-> Should return ipv6 DNS Cluster IP when given dns-cluster-ip"
exit_code=0
TEMP_DIR=$(mktemp -d)
run ${TEMP_DIR} /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv6 \
    --dns-cluster-ip fe80::2a \
    test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
    echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
    exit 1
fi

cluster_dns=$(jq -r '.clusterDNS[0]' < ${TEMP_DIR}/kubelet-config.json)
if [[ ${cluster_dns} != 'fe80::2a' ]]; then
    echo "❌ Test Failed: expected clusterDNS IP 'fe80::2a' but got '${cluster_dns}'"
    exit 1
fi