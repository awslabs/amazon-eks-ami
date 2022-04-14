#!/usr/bin/env bash
# set -x
export LANG="C"
export LC_ALL="C"
readonly CURRENT_TIME=$(date +%Y-%m-%d_%H%M-%Z)
readonly COLLECT_DIR="kubectl-output-${CURRENT_TIME}"
mv ${COLLECT_DIR} ${COLLECT_DIR}_bk 2>/dev/null
mkdir -p ${COLLECT_DIR}

try() {
  local action=$*
  echo -ne "Trying... $action "
}

warning() {
  local reason=$*
  echo -e "\n\n\tWarning: $reason "
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

kubectl_get_specific_resource() {
  object_type=$1
  resource_name=$2
  namespace_name=$3
  try "kubectl get ${object_type} ${resource_name} -n ${namespace_name} -o yaml"
  kubectl get ${object_type} ${resource_name} -n ${namespace_name} -o yaml > ${COLLECT_DIR}/kubectl-get-${object_type}-${resource_name}-${namespace_name}-${CURRENT_TIME}.yaml
  ok
}

kubectl_get() {
  object=$1
  try "kubectl get ${object} --all-namespaces -o wide"
  kubectl get ${object} --all-namespaces -o wide > ${COLLECT_DIR}/kubectl-get-${object}-${CURRENT_TIME}.log
  ok
}

# object_type,resource_name,namespace. Example:pods,test-pod,kube-system
list_get_yaml=(
  'configmap,aws-auth,kube-system'
  'daemonset,aws-node,kube-system'
  'daemonset,kube-proxy,kube-system'
  'configmap,kube-proxy,kube-system'
  'configmap,kube-proxy-config,kube-system'
  'deployment,coredns,kube-system'
  'configmap,corednskube-system'
)

# get object for a specific resource in a namespace. Example: kubectl get configmap aws-auth -n kube-system -o yaml
for each_get_yaml in ${list_get_yaml[@]}
do
  # split sub-list if available
  if [[ $each_get_yaml == *","*","* ]]
  then
      # split server name from sub-list
      tmpArray=(${each_get_yaml//,/ })
      object_type=${tmpArray[0]}
      resource_name=${tmpArray[1]}
      namespace_name=${tmpArray[2]}

      # kubectl_get_specific_resource will get yaml of specific resource. Example: kubectl get daemonset aws-node -n kube-system -o yaml
      kubectl_get_specific_resource $object_type $resource_name $namespace_name
  else
    warning "Unable to parse ${each_get_yaml}. Skipped kubectl get YAML configuration for ${each_get_yaml}."
  fi
done

# get resources (-o wide) for a kubernetes object from all namespaces. Example: kubectl get pods --all-namespaces -o wide
for each_resource in $(kubectl api-resources | awk -F' ' '{print $1}' | grep -iv "name")
do
  kubectl_get $each_resource
done

pack
finished