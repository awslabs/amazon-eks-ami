#!/usr/bin/env bash
set -euo pipefail

echo "--> Should return IPv4 DNS Cluster IP when given dns-cluster-ip"
exit_code=0
TEMP_DIR=$(mktemp -d)
run ${TEMP_DIR} /etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv4 \
    --dns-cluster-ip 192.168.0.1 \
    test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
    echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
    exit 1
fi

cluster_dns=$(jq -r '.clusterDNS[0]' < ${TEMP_DIR}/kubelet-config.json)
if [[ ${cluster_dns} != '192.168.0.1' ]]; then
    echo "❌ Test Failed: expected clusterDNS IP '192.168.0.1' but got '${cluster_dns}'"
    exit 1
fi