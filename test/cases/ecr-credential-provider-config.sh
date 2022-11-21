#!/usr/bin/env bash
set -euo pipefail

exit_code=0
TEMP_DIR=$(mktemp -d)

export CRED_PROVIDER_FILE="/etc/eks/ecr-credential-provider/ecr-credential-provider-config"
export CRED_PROVIDER_RESET_FILE="./cred-provider-config"

# Store the original version of the config
cp $CRED_PROVIDER_FILE $CRED_PROVIDER_RESET_FILE
# Reset the file that may have changed
function reset_scenario {
  echo "Resetting test scenario"
  cp $CRED_PROVIDER_RESET_FILE $CRED_PROVIDER_FILE
}

echo "--> Should default to credentialprovider.kubelet.k8s.io/v1alpha1 and kubelet.config.k8s.io/v1alpha1 when below k8s version 1.24"
reset_scenario

# This variable is used to override the default value in the kubelet mock
export KUBELET_VERSION=v1.22.15-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${exit_code}'"
  exit 1
fi

expected_cred_provider_api="credentialprovider.kubelet.k8s.io/v1alpha1"
actual=$(yq e '.providers[0].apiVersion' $CRED_PROVIDER_FILE)
if [[ "$expected_cred_provider_api" != "$actual" ]]; then
  echo "❌ Test Failed: expected 1.22 credential provider file to contain $expected_cred_provider_api"
  exit 1
fi

expected_kubelet_config_api="kubelet.config.k8s.io/v1alpha1"
actual=$(yq e '.apiVersion' $CRED_PROVIDER_FILE)
if [[ "$expected_kubelet_config_api" != "$actual" ]]; then
  echo "❌ Test Failed: expected 1.22 credential provider file to contain $expected_kubelet_config_api"
  exit 1
fi

echo "--> Should default to credentialprovider.kubelet.k8s.io/v1beta1 and kubelet.config.k8s.io/v1beta1 when at or above k8s version 1.24"
reset_scenario

export KUBELET_VERSION=v1.24.15-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a zero exit code but got '${exit_code}'"
  exit 1
fi

expected_cred_provider_api="credentialprovider.kubelet.k8s.io/v1beta1"
actual=$(yq e '.providers[0].apiVersion' $CRED_PROVIDER_FILE)
if [[ "$expected_cred_provider_api" != "$actual" ]]; then
  echo "❌ Test Failed: expected 1.24 credential provider file to contain $expected_cred_provider_api"
  exit 1
fi

expected_kubelet_config_api="kubelet.config.k8s.io/v1beta1"
actual=$(yq e '.apiVersion' $CRED_PROVIDER_FILE)
if [[ "$expected_kubelet_config_api" != "$actual" ]]; then
  echo "❌ Test Failed: expected 1.24 credential provider file to contain $expected_kubelet_config_api"
  exit 1
fi

exit_code=0
