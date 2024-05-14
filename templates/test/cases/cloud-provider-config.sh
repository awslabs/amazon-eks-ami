#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

KUBELET_UNIT_DIR="/etc/systemd/system/kubelet.service.d"
KUBELET_CONFIG_FILE="/etc/kubernetes/kubelet/kubelet-config.json"

function fail() {
  echo "❌ Test Failed:" "$@"
  echo "Kubelet systemd units:"
  find $KUBELET_UNIT_DIR -type f | xargs cat
  echo "Kubelet config file:"
  cat $KUBELET_CONFIG_FILE | jq '.'
  exit 1
}

EXPECTED_PROVIDER_ID=$(provider-id)

echo "--> Should use in-tree cloud provider below k8s version 1.26"
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
ACTUAL_PROVIDER_ID=$(jq -r '.providerID' $KUBELET_CONFIG_FILE)
if [ ! "$ACTUAL_PROVIDER_ID" = "null" ]; then
  fail "expected .providerID to be absent in kubelet's config file but was '$ACTUAL_PROVIDER_ID'"
fi

echo "--> Should use external cloud provider at k8s version 1.26"
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
ACTUAL_PROVIDER_ID=$(jq -r '.providerID' $KUBELET_CONFIG_FILE)
if [ ! "$ACTUAL_PROVIDER_ID" = "$EXPECTED_PROVIDER_ID" ]; then
  fail "expected .providerID=$EXPECTED_PROVIDER_ID to be present in kubelet's config file but was '$ACTUAL_PROVIDER_ID'"
fi

echo "--> Should use external cloud provider above k8s version 1.26"
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
ACTUAL_PROVIDER_ID=$(jq -r '.providerID' $KUBELET_CONFIG_FILE)
if [ ! "$ACTUAL_PROVIDER_ID" = "$EXPECTED_PROVIDER_ID" ]; then
  fail "expected .providerID=$EXPECTED_PROVIDER_ID to be present in kubelet's config file but was '$ACTUAL_PROVIDER_ID"
fi
