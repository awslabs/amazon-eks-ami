#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: ${0} KUBERNETES_VERSION"
  exit 1
fi

K8S_VER="${1}"

CLUSTER_NAME="hack-${K8S_VER//./}"
CLUSTER_INFO=$(mktemp)
NODEGROUP_INFO=$(mktemp)

function log() {
  echo >&2 "$@"
}

function find-public-key() {
  COMMON_PUB_KEY_LOCATIONS=("${HOME}/.ssh/id_rsa.pub" "${HOME}/.ssh/id_ed25519.pub")
  for PUB_KEY in "${COMMON_PUB_KEY_LOCATIONS[@]}"; do
    if [ -f "${PUB_KEY}" ]; then
      echo "${PUB_KEY}"
      return 0
    fi
  done
  log "No SSH public key found, checked common locations: [${COMMON_PUB_KEY_LOCATIONS[@]}]"
  exit 1
}

function get-cluster-info() {
  eksctl get cluster --name "${CLUSTER_NAME}" --output json | jq -c . > "${CLUSTER_INFO}"
}

function get-nodegroup-info() {
  eksctl get nodegroups --cluster "${CLUSTER_NAME}" --output json | jq -c . > "${NODEGROUP_INFO}"
}

function create-cluster() {
  PUB_KEY=$(find-public-key)
  eksctl create cluster \
    --name="${CLUSTER_NAME}" \
    --version="${K8S_VER}" \
    --nodes=0 \
    --managed=false \
    --ssh-access=true \
    --ssh-public-key=${PUB_KEY} \
    1>&2
}

if ! get-cluster-info 2> /dev/null; then
  log "No ${K8S_VER} hacking cluster found, creating one now. This will take a bit!"
  create-cluster
  get-cluster-info
fi
get-nodegroup-info

CLUSTER_NAME=$(jq -r .[0].Name "${CLUSTER_INFO}")
SUBNET_ID=$(jq -r .[0].ResourcesVpcConfig.SubnetIds[0] "${CLUSTER_INFO}")
CLUSTER_CA=$(jq -r .[0].CertificateAuthority.Data "${CLUSTER_INFO}")
CLUSTER_ENDPOINT=$(jq -r .[0].Endpoint "${CLUSTER_INFO}")
NODE_ROLE_ARN=$(jq -r .[0].NodeInstanceRoleARN "${NODEGROUP_INFO}")
NODE_ROLE_NAME=$(echo "${NODE_ROLE_ARN}" | rev | cut -d'/' -f1 | rev)
NODE_INSTANCE_PROFILE=$(aws iam list-instance-profiles-for-role --role-name ${NODE_ROLE_NAME} | jq -r .InstanceProfiles[0].InstanceProfileName)
LAUNCH_TEMPLATE_ID=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $(jq -r .[0].AutoScalingGroupName ${NODEGROUP_INFO}) | jq -r .AutoScalingGroups[0].LaunchTemplate.LaunchTemplateId)
SECURITY_GROUP_IDS=$(aws ec2 describe-launch-template-versions --launch-template-id ${LAUNCH_TEMPLATE_ID} | jq -r '.LaunchTemplateVersions[0].LaunchTemplateData.NetworkInterfaces[0].Groups | join(",")')

echo "-var hack=true -var subnet_id=${SUBNET_ID} -var security_group_ids='${SECURITY_GROUP_IDS}' -var iam_instance_profile=${NODE_INSTANCE_PROFILE} -var hack_bootstrap_args='${CLUSTER_NAME} --b64-cluster-ca ${CLUSTER_CA} --apiserver-endpoint ${CLUSTER_ENDPOINT}'"
