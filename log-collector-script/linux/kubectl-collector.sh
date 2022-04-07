#!/usr/bin/env bash
export LANG="C"
export LC_ALL="C"
readonly CURRENT_TIME=$(date +%Y-%m-%d_%H%M-%Z)
readonly COLLECT_DIR="kubectl-output-${CURRENT_TIME}"
mv ${COLLECT_DIR} ${COLLECT_DIR}_bk 2>/dev/null
mkdir -p ${COLLECT_DIR}
try() {
  local action=$*
  echo -n "Trying to $action... "
}
ok() {
  echo
}
pack() {
  try "archive gathered information"
  tar --create --verbose --gzip --file ${PWD}/eks_kubectl_commands_"${CURRENT_TIME}".tar.gz --directory="${COLLECT_DIR}" . > /dev/null 2>&1
  ok
}
finished() {
  echo -e "\n\t Done... your kubectl command logs are located in \n \n \t ${PWD}/eks_kubectl_commands_"${CURRENT_TIME}".tar.gz \n"
}
try "get all Kubernetes Objects"
kubectl get all --all-namespaces -o wide > ${COLLECT_DIR}/kubectl-get-all-${CURRENT_TIME}.log
ok
try "get DaemonSet aws-node"
kubectl get daemonset aws-node -n kube-system -o yaml > ${COLLECT_DIR}/kubectl-get-aws-node-${CURRENT_TIME}.yaml
ok
try "get Deployment coredns"
kubectl get deployment coredns -n kube-system -o yaml > ${COLLECT_DIR}/kubectl-get-coredns-${CURRENT_TIME}.yaml
ok
try "get all nodes"
kubectl get nodes -o wide > ${COLLECT_DIR}/kubectl-get-nodes-${CURRENT_TIME}.log
ok
try "get all validatingwebhookconfigurations"
kubectl get validatingwebhookconfigurations > ${COLLECT_DIR}/kubectl-get-validatingwebhooks-${CURRENT_TIME}.log
ok
try "get all mutatingwebhookconfigurations"
kubectl get mutatingwebhookconfigurations > ${COLLECT_DIR}/kubectl-get-mutatingwebhooks-${CURRENT_TIME}.log
ok
try "get all apiservices"
kubectl get apiservices > ${COLLECT_DIR}/kubectl-get-apiservices-${CURRENT_TIME}.log
ok
try "get all PersistentVolumes"
kubectl get persistentvolumes -o wide > ${COLLECT_DIR}/kubectl-get-pv-${CURRENT_TIME}.log
ok
try "get all PersistentVolumeClaims"
kubectl get persistentvolumeclaims --all-namespaces -o wide > ${COLLECT_DIR}/kubectl-get-pvc-all-namespaces-${CURRENT_TIME}.log
ok
try "get all StorageClasses"
kubectl get storageclass -o wide > ${COLLECT_DIR}/kubectl-get-sc-${CURRENT_TIME}.log
ok
try "get all serviceaccount"
kubectl get serviceaccount --all-namespaces -o wide > ${COLLECT_DIR}/kubectl-get-serviceaccount-${CURRENT_TIME}.log
ok
try "get ConfigMap aws-auth"
kubectl get configmap aws-auth -n kube-system -o yaml > ${COLLECT_DIR}/kubectl-get-aws-auth-configmap-${CURRENT_TIME}.yaml
ok
try "get ConfigMap coredns"
kubectl get configmap coredns -n kube-system -o yaml > ${COLLECT_DIR}/kubectl-get-coredns-configmap-${CURRENT_TIME}.yaml
ok
try "get ConfigMap kube-proxy"
kubectl get configmap kube-proxy -n kube-system -o yaml > ${COLLECT_DIR}/kubectl-get-kube-proxy-configmap-${CURRENT_TIME}.yaml
kubectl get configmap kube-proxy-config -n kube-system -o yaml > ${COLLECT_DIR}/kubectl-get-kube-proxy-config-configmap-${CURRENT_TIME}.yaml
ok
try "get all NetworkPolicies"
kubectl get networkpolicies --all-namespaces -o wide > ${COLLECT_DIR}/kubectl-get-netpol-all-namespaces-${CURRENT_TIME}.log
ok
try "get all Endpoints"
kubectl get endpoints --all-namespaces -o wide > ${COLLECT_DIR}/kubectl-get-endpoints-${CURRENT_TIME}.log
ok
try "get Clusterrole"
kubectl get clusterrole > ${COLLECT_DIR}/kubectl-get-endpoints-${CURRENT_TIME}.log
ok
pack
finished
