#!/usr/bin/env bash

set -o errexit
set -o pipefail

MAX_AGE_SECONDS=${MAX_AGE_SECONDS:-$1}
if [ -z "${MAX_AGE_SECONDS}" ]; then
  echo "usage: $0 MAX_AGE_SECONDS"
  exit 1
fi

set -o nounset

# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-retries.html
AWS_RETRY_MODE=standard
AWS_MAX_ATTEMPTS=5

function iso8601_is_eligible_for_deletion() {
  local TIME_IN_ISO8601="$1"
  local TIME_IN_SECONDS=$(date -d "$TIME_IN_ISO8601" '+%s')
  local CURRENT_TIME_IN_SECONDS=$(date '+%s')
  MIN_TIME_SECONDS=$(($CURRENT_TIME_IN_SECONDS - $MAX_AGE_SECONDS))
  [ "$TIME_IN_SECONDS" -lt "$MIN_TIME_SECONDS" ]
}
function cluster_is_eligible_for_deletion() {
  local CLUSTER_NAME="$1"
  local CREATED_AT_ISO8601=$(aws eks describe-cluster --name $CLUSTER_NAME --query 'cluster.createdAt' --output text)
  iso8601_is_eligible_for_deletion "$CREATED_AT_ISO8601"
}
function nodegroup_is_eligible_for_deletion() {
  local CLUSTER_NAME="$1"
  local NODEGROUP_NAME="$2"
  local CREATED_AT_ISO8601=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name $NODEGROUP_NAME --query 'nodegroup.createdAt' --output text)
  iso8601_is_eligible_for_deletion "$CREATED_AT_ISO8601"
}
wget --no-verbose -O eksctl.tar.gz "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
tar xf eksctl.tar.gz && chmod +x ./eksctl
for CLUSTER in $(aws eks list-clusters --query 'clusters[]' --output text); do
  for NODEGROUP in $(aws eks list-nodegroups --cluster-name $CLUSTER --query 'nodegroups[]' --output text); do
    if nodegroup_is_eligible_for_deletion $CLUSTER $NODEGROUP; then
      ./eksctl delete nodegroup --cluster $CLUSTER --name $NODEGROUP
    fi
  done
  if [ "$(aws eks list-nodegroups --cluster-name $CLUSTER --output json | jq '.nodegroups | length')" -gt 0 ]; then
    echo "Skipping cluster $CLUSTER"
  elif cluster_is_eligible_for_deletion $CLUSTER; then
    echo "Deleting cluster $CLUSTER"
    ./eksctl delete cluster --name "$CLUSTER"
  fi
done
