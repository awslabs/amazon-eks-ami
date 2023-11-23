#!/usr/bin/env bash
set -euo pipefail

TEMP_DIR=$(mktemp -d)

cp /etc/eks/containerd/containerd-config.toml ${TEMP_DIR}/containerd-config.toml

echo "--> Default pause container image be ecr"
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --container-runtime containerd \
  test

expected_image="sandbox_image = \"602401143452.dkr.ecr.us-east-1.amazonaws.com/eks/pause:3.5\""
actual_image=$(cat /etc/containerd/config.toml | grep "sandbox_image")

if [[ ${actual_image} != ${expected_image} ]]; then
  echo "❌ Test Failed: expected sandbox_image '${expected_image}' but got '${actual_image}'"
  exit 1
fi

echo "--> Set pause container image"
cp ${TEMP_DIR}/containerd-config.toml /etc/eks/containerd/containerd-config.toml
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --container-runtime containerd \
  --pause-container-image "sample:8443/registry/pause" \
  test || exit_code=$?

expected_image='sandbox_image = "sample:8443/registry/pause:3.5"'
actual_image=$(cat /etc/containerd/config.toml | grep "sandbox_image")

if [[ ${actual_image} != ${expected_image} ]]; then
  echo "❌ Test Failed: expected sandbox_image '${expected_image}' but got '${actual_image}'"
  exit 1
fi

cp ${TEMP_DIR}/containerd-config.toml /etc/eks/containerd/containerd-config.toml
