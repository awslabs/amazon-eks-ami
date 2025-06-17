#!/usr/bin/env bash
set -euo pipefail

echo "-> Should fail validation - IPv6 cluster with  mismatch --service-ipv4-cidr set"
exit_code=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --ip-family ipv6 \
  --service-ipv4-cidr 192.168.0.0/24 \
  ipv4-cluster || exit_code=$?

if [[ ${exit_code} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi
