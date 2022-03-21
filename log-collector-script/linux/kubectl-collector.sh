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
try "describe DaemonSet aws-node"
kubectl describe daemonset aws-node -n kube-system > ${COLLECT_DIR}/describe-aws-node-${CURRENT_TIME}.log
ok
try "describe Deployment coredns"
kubectl describe deployment coredns -n kube-system > ${COLLECT_DIR}/describe-coredns-${CURRENT_TIME}.log
ok
try "get all nodes"
kubectl get nodes > ${COLLECT_DIR}/kubectl-get-nodes-${CURRENT_TIME}.log
ok
try "get all validatingwebhookconfigurations"
kubectl get validatingwebhookconfigurations > ${COLLECT_DIR}/validatingwebhooks-${CURRENT_TIME}.log
ok
try "get all mutatingwebhookconfigurations"
kubectl get mutatingwebhookconfigurations > ${COLLECT_DIR}/mutatingwebhooks-${CURRENT_TIME}.log
ok
try "get all apiservices"
kubectl get apiservices > ${COLLECT_DIR}/apiservices-${CURRENT_TIME}.log
ok
try "get all PersistentVolumes"
kubectl get persistentvolumes -o yaml > ${COLLECT_DIR}/get-pv-${CURRENT_TIME}.yml
ok
try "get all PersistentVolumeClaims"
kubectl get persistentvolumeclaims --all-namespaces -o yaml > ${COLLECT_DIR}/get-pvs-all-namespaces-${CURRENT_TIME}.yml
ok
try "get all StorageClasses"
kubectl get storageclass -o yaml > ${COLLECT_DIR}/get-sc-${CURRENT_TIME}.yml
ok
try "get all serviceaccount"
kubectl get serviceaccount --all-namespaces -o yaml > ${COLLECT_DIR}/get-serviceaccount-${CURRENT_TIME}.yml
ok
try "get ConfigMap aws-auth"
kubectl get configmap aws-auth -n kube-system -o yaml > ${COLLECT_DIR}/aws-auth-configmap-${CURRENT_TIME}.yml
ok
try "get ConfigMap coredns"
kubectl get configmap coredns -n kube-system -o yaml > ${COLLECT_DIR}/coredns-configmap-${CURRENT_TIME}.yml
ok
try "get all NetworkPolicies"
kubectl get networkpolicies --all-namespaces -o yaml > ${COLLECT_DIR}/netpol-all-namespaces-${CURRENT_TIME}.yml
ok
try "get all Endpoints"
kubectl get endpoints --all-namespaces -o yaml > ${COLLECT_DIR}/get-endpoints-${CURRENT_TIME}.yml
ok
pack
finished
