#!/usr/bin/env bash
set -euo pipefail

echo "-> Should not set systemReservedCgroup and kubeReservedCgroup when --reserved-cpus is set with containerd"
exit_code=0
export KUBELET_VERSION=v1.24.15-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --kubelet-extra-args '--node-labels=cnf=cnf1 --reserved-cpus=0-3 --cpu-manager-policy=static' \
  ipv4-cluster || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

KUBELET_CONFIG=/etc/kubernetes/kubelet/kubelet-config.json
if grep -q systemReservedCgroup ${KUBELET_CONFIG}; then
  echo "❌ Test Failed: expected systemReservedCgroup to be absent in ${KUBELET_CONFIG}.Found: $(grep systemReservedCgroup ${KUBELET_CONFIG})"
  exit 1
fi

if grep -q kubeReservedCgroup ${KUBELET_CONFIG}; then
  echo "❌ Test Failed: expected kubeReservedCgroup to be absent ${KUBELET_CONFIG}.Found: $(grep kubeReservedCgroup ${KUBELET_CONFIG})"
  exit 1
fi

echo "-> Should set systemReservedCgroup and kubeReservedCgroup when --reserved-cpus is not set with containerd"
exit_code=0
export KUBELET_VERSION=v1.24.15-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  ipv4-cluster || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

if ! $(grep -q systemReservedCgroup ${KUBELET_CONFIG}); then
  echo "❌ Test Failed: expected systemReservedCgroup to be present in ${KUBELET_CONFIG}. Found: $(grep systemReservedCgroup ${KUBELET_CONFIG})"
  exit 1
fi

if ! $(grep -q kubeReservedCgroup ${KUBELET_CONFIG}); then
  echo "❌ Test Failed: expected kubeReservedCgroup to be present ${KUBELET_CONFIG}.Found: $(grep kubeReservedCgroup ${KUBELET_CONFIG})"
  exit 1
fi

echo "-> Should set systemReservedCgroup and kubeReservedCgroup when --reserved-cpus is set with dockerd"
exit_code=0
export KUBELET_VERSION=v1.23.15-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  ipv4-cluster || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

if ! $(grep -q systemReservedCgroup ${KUBELET_CONFIG}); then
  echo "❌ Test Failed: expected systemReservedCgroup to be present in ${KUBELET_CONFIG}.Found: $(grep systemReservedCgroup ${KUBELET_CONFIG})"
  exit 1
fi

if ! $(grep -q kubeReservedCgroup ${KUBELET_CONFIG}); then
  echo "❌ Test Failed: expected kubeReservedCgroup to be present ${KUBELET_CONFIG}.Found: $(grep kubeReservedCgroup ${KUBELET_CONFIG})"
  exit 1
fi
