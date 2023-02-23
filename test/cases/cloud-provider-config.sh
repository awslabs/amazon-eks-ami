#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

KUBELET_UNIT_DIR="/etc/systemd/system/kubelet.service.d"

function fail() {
  echo "❌ Test Failed:" "$@"
  find $KUBELET_UNIT_DIR -type f | xargs cat
  exit 1
}

echo "--> Should use in-tree cloud provider when below k8s version 1.26"
# This variable is used to override the default value in the kubelet mock
export KUBELET_VERSION=v1.25.5-eks-ba74326
EXIT_CODE=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected a zero exit code but got '${EXIT_CODE}'"
fi
EXIT_CODE=0
grep -RFq -e "--cloud-provider=aws" $KUBELET_UNIT_DIR || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected --cloud-provider=aws to be present in kubelet's systemd units"
fi
EXIT_CODE=0
grep -RFq -e "--provider-id=$(provider-id)" $KUBELET_UNIT_DIR || EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
  fail "expected --provider-id=$(provider-id) to be absent in kubelet's systemd units"
fi

echo "--> Should use external cloud provider when at or above k8s version 1.26"
# at 1.26
export KUBELET_VERSION=v1.26.5-eks-ba74326
EXIT_CODE=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected a zero exit code but got '${EXIT_CODE}'"
fi
EXIT_CODE=0
grep -RFq -e "--cloud-provider=external" $KUBELET_UNIT_DIR || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected --cloud-provider=external to be present in kubelet's systemd units"
fi
EXIT_CODE=0
grep -RFq -e "--provider-id=$(provider-id)" $KUBELET_UNIT_DIR || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected --provider-id=$(provider-id) to be present in kubelet's systemd units"
fi
# above 1.26
export KUBELET_VERSION=v1.27.0-eks-ba74326
EXIT_CODE=0
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected a zero exit code but got '${EXIT_CODE}'"
fi
EXIT_CODE=0
grep -RFq -e "--cloud-provider=external" $KUBELET_UNIT_DIR || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected --cloud-provider=external to be present in kubelet's systemd units"
fi
EXIT_CODE=0
grep -RFq -e "--provider-id=$(provider-id)" $KUBELET_UNIT_DIR || EXIT_CODE=$?
if [[ ${EXIT_CODE} -ne 0 ]]; then
  fail "expected --provider-id=$(provider-id) to be present in kubelet's systemd units"
fi
