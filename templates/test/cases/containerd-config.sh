#!/usr/bin/env bash
set -euo pipefail

exit_code=0

echo "--> Default containerd config file should be valid"
STDERR_FILE=$(mktemp)
containerd -c /etc/eks/containerd/containerd-config.toml config dump > /dev/null 2> "$STDERR_FILE" || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: default containerd config file is invalid! $(cat "$STDERR_FILE")"
  exit 1
fi

echo "--> Should fail when given an invalid containerd config"
CONTAINERD_TOML=$(mktemp containerd-XXXXX.toml)
cat > "$CONTAINERD_TOML" << EOF
[cgroup]
path = "foo"
[cgroup]
path = "bar"
EOF

export KUBELET_VERSION=v1.24.15-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --container-runtime containerd \
  --containerd-config-file "$CONTAINERD_TOML" \
  ipv4-cluster || exit_code=$?

if [[ ${exit_code} -eq 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi
