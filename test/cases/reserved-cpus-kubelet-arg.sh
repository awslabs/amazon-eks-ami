#!/usr/bin/env bash
set -euo pipefail

echo "-> Should not set systemReservedCgroup and kubeReservedCgroup when --reserved-cpus is set with containerd"
exit_code=0
export KUBELET_VERSION=v1.24.15-eks-ba74326
runtime="containerd"
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  --kubelet-extra-args '--node-labels=cnf=cnf1 --reserved-cpus=0-3 --cpu-manager-policy=static' \
  test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

if grep -q systemReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json; then
  echo "❌ Test Failed: expected systemReservedCgroup to be absent from /etc/kubernetes/kubelet/kubelet-config.json. expected: 1 Received: ${retCode}"
  exit 1
fi

retCode=$(
  grep -q kubeReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json
  echo $?
)
if [[ ${retCode} -eq 0 ]]; then
  echo "❌ Test Failed: expected kubeReservedCgroup to be absent from /etc/kubernetes/kubelet/kubelet-config.json. expected: 1 Received: ${retCode}"
  exit 1
fi

echo "-> Should set systemReservedCgroup and kubeReservedCgroup when --reserved-cpus is not set with containerd"
exit_code=0
export KUBELET_VERSION=v1.24.15-eks-ba74326
runtime="containerd"
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

retCode=$(
  grep -q systemReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json
  echo $?
)
if [[ ${retCode} -ne 0 ]]; then
  echo "❌ Test Failed: expected systemReservedCgroup to be retCode in /etc/kubernetes/kubelet/kubelet-config.json. expected: /system Received: $(grep -q systemReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json) "
  exit 1
fi

retCode=$(
  grep -q kubeReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json
  echo $?
)
if [[ ${retCode} -ne 0 ]]; then
  echo "❌ Test Failed: expected kubeReservedCgroup to be absent from /etc/kubernetes/kubelet/kubelet-config.json. expected: /runtime Received: $(grep -q kubeReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json) "
  exit 1
fi

echo "-> Should set systemReservedCgroup and kubeReservedCgroup when --reserved-cpus is set with dockerd"
exit_code=0
export KUBELET_VERSION=v1.23.15-eks-ba74326
/etc/eks/bootstrap.sh \
  --b64-cluster-ca dGVzdA== \
  --apiserver-endpoint http://my-api-endpoint \
  test || exit_code=$?

if [[ ${exit_code} -ne 0 ]]; then
  echo "❌ Test Failed: expected a non-zero exit code but got '${exit_code}'"
  exit 1
fi

retCode=$(
  grep -q systemReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json
  echo $?
)
if [[ ${retCode} -ne 0 ]]; then
  echo "❌ Test Failed: expected systemReservedCgroup to be retCode in /etc/kubernetes/kubelet/kubelet-config.json. expected: /system Received: $(grep -q systemReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json) "
  exit 1
fi

retCode=$(
  grep -q kubeReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json
  echo $?
)
if [[ ${retCode} -ne 0 ]]; then
  echo "❌ Test Failed: expected kubeReservedCgroup to be absent from /etc/kubernetes/kubelet/kubelet-config.json. expected: /runtime Received: $(grep -q kubeReservedCgroup /etc/kubernetes/kubelet/kubelet-config.json) "
  exit 1
fi
