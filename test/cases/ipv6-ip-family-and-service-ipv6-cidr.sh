#!/usr/bin/env bash
set -euo pipefail

echo "-> Should fail w/ \"service-ipv6-cidr must be provided when ip-family is specified as ipv6\""
exit_code=0
/etc/eks/bootstrap.sh \
    --b64-cluster-ca dGVzdA== \
    --apiserver-endpoint http://my-api-endpoint \
    --ip-family ipv6 \
    test || exit_code=$?

if [[ ${exit_code} -eq 0 ]]; then
    echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
    exit 1
fi