#!/usr/bin/env bash

set -euo pipefail
export AWS_PAGER=""

usage() {
  cat << 'EOF'
Build a standard AL2023 EKS AMI using SSM Run Command, without SSH or Packer.

Required environment variables:
  K8S                  Kubernetes minor version, e.g. 1.37
  SUBNET_ID            Builder subnet with outbound repository and SSM access
  SECURITY_GROUP_ID    Existing builder security group; no inbound SSH required
  ARTIFACT_BUCKET      Existing private S3 bucket in the build region
  AMI_NAME             Unique name for the resulting private AMI

Optional:
  REGION               AWS region (default: ca-central-1)
  ARCH                 x86_64 (default) or arm64
  INSTANCE_TYPE        Default: m5.xlarge or m6g.xlarge, respectively
  INSTANCE_PROFILE     Existing profile; otherwise create a temporary role/profile
  SOURCE_AMI_ID        SSM-ready AL2023 image; otherwise discover a standard image
  KMS_KEY_ID           Customer-managed key for the encrypted builder volume
  KUBERNETES_VERSION   Pin binaries (requires KUBERNETES_BUILD_DATE too)
  KUBERNETES_BUILD_DATE
  SSM_TIMEOUT_SECONDS  Provisioning timeout (default: 14400)

From the repository root: bash hack/build-ssm.sh
This does not read Packer variable files. Uses the normal AWS credential chain.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ "$#" != 0 ]]; then
  usage >&2
  exit 1
fi

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for tool in aws jq tar; do
  command -v "${tool}" > /dev/null || fail "Required command not found: ${tool}"
done
for name in K8S SUBNET_ID SECURITY_GROUP_ID ARTIFACT_BUCKET AMI_NAME; do
  [[ -n "${!name:-}" ]] || fail "Set ${name}. See --help."
done

REGION="${REGION:-ca-central-1}"
ARCH="${ARCH:-x86_64}"
SSM_TIMEOUT_SECONDS="${SSM_TIMEOUT_SECONDS:-14400}"
[[ "${K8S}" =~ ^[0-9]+\.[0-9]+$ ]] || fail "K8S must be a minor version, e.g. 1.37."
[[ "${ARCH}" == x86_64 || "${ARCH}" == arm64 ]] || fail "Unsupported ARCH: ${ARCH}"
[[ "${ARTIFACT_BUCKET}" =~ ^[a-z0-9][a-z0-9.-]+[a-z0-9]$ ]] || fail "Invalid ARTIFACT_BUCKET."
[[ "${AMI_NAME}" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]{2,127}$ ]] \
  || fail "AMI_NAME must be 3-128 letters, digits, dots, underscores, or hyphens."
[[ "${SSM_TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]] || fail "SSM_TIMEOUT_SECONDS must be a positive integer."
if [[ "${ARCH}" == arm64 ]]; then
  INSTANCE_TYPE="${INSTANCE_TYPE:-m6g.xlarge}"
else
  INSTANCE_TYPE="${INSTANCE_TYPE:-m5.xlarge}"
fi

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RUN_ID="eks-ami-ssm-$(date -u +%Y%m%dT%H%M%SZ)-$$"
PREFIX="${RUN_ID}"
WORK=$(mktemp -d)
INSTANCE_ID=""
COMMAND_ID=""
ROLE_CREATED=false
PROFILE_CREATED=false
ROLE_ATTACHED=false
POLICY_ATTACHED=false
PROFILE_ROLE_ATTACHED=false
ARCHIVE_UPLOADED=false
INSTANCE_PROFILE="${INSTANCE_PROFILE:-}"

aws() {
  command aws --region "${REGION}" "$@"
}

cleanup() {
  local result=$?
  trap - EXIT INT TERM
  set +e
  if [[ -n "${COMMAND_ID}" ]]; then
    aws ssm cancel-command --command-id "${COMMAND_ID}" --instance-ids "${INSTANCE_ID}" > /dev/null \
      || {
        echo "WARNING: Could not cancel ${COMMAND_ID}." >&2
        result=1
      }
  fi
  if [[ -n "${INSTANCE_ID}" ]]; then
    if ! aws ec2 terminate-instances --instance-ids "${INSTANCE_ID}" > /dev/null \
      || ! aws ec2 wait instance-terminated --instance-ids "${INSTANCE_ID}"; then
      echo "WARNING: Check builder ${INSTANCE_ID}; termination failed." >&2
      result=1
    fi
  fi
  if [[ "${PROFILE_ROLE_ATTACHED}" == true ]]; then
    aws iam remove-role-from-instance-profile --instance-profile-name "${RUN_ID}" --role-name "${RUN_ID}" \
      || {
        echo "WARNING: Could not detach role from ${RUN_ID}." >&2
        result=1
      }
  fi
  if [[ "${PROFILE_CREATED}" == true ]]; then
    aws iam delete-instance-profile --instance-profile-name "${RUN_ID}" \
      || {
        echo "WARNING: Could not delete instance profile ${RUN_ID}." >&2
        result=1
      }
  fi
  if [[ "${POLICY_ATTACHED}" == true ]]; then
    aws iam delete-role-policy --role-name "${RUN_ID}" --policy-name BuildArtifacts \
      || {
        echo "WARNING: Could not delete inline policy on ${RUN_ID}." >&2
        result=1
      }
  fi
  if [[ "${ROLE_ATTACHED}" == true ]]; then
    aws iam detach-role-policy --role-name "${RUN_ID}" --policy-arn "${SSM_POLICY_ARN}" \
      || {
        echo "WARNING: Could not detach SSM policy on ${RUN_ID}." >&2
        result=1
      }
  fi
  if [[ "${ROLE_CREATED}" == true ]]; then
    aws iam delete-role --role-name "${RUN_ID}" \
      || {
        echo "WARNING: Could not delete role ${RUN_ID}." >&2
        result=1
      }
  fi
  if [[ "${ARCHIVE_UPLOADED}" == true ]]; then
    aws s3 rm "s3://${ARTIFACT_BUCKET}/${PREFIX}/source.tar.gz" \
      || {
        echo "WARNING: Could not delete uploaded source archive." >&2
        result=1
      }
  fi
  rm -f "${WORK}/build-config.json" "${WORK}/source.tar.gz" "${WORK}/trust.json" \
    "${WORK}/policy.json" "${WORK}/launch.json" "${WORK}/parameters.json"
  rmdir "${WORK}" || {
    echo "WARNING: Could not remove temporary directory ${WORK}." >&2
    result=1
  }
  exit "${result}"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

IDENTITY=$(aws sts get-caller-identity --output json)
PARTITION=$(jq -r '.Arn | split(":")[1]' <<< "${IDENTITY}")
ACCOUNT_ID=$(jq -r '.Account' <<< "${IDENTITY}")
aws s3api head-bucket --bucket "${ARTIFACT_BUCKET}" --expected-bucket-owner "${ACCOUNT_ID}"
SSM_POLICY_ARN="arn:${PARTITION}:iam::aws:policy/AmazonSSMManagedInstanceCore"

if [[ -z "${KUBERNETES_VERSION:-}" && -z "${KUBERNETES_BUILD_DATE:-}" ]]; then
  BINARIES=$(bash "${ROOT}/hack/latest-binaries.sh" "${K8S}" "${REGION}")
  KUBERNETES_VERSION=$(awk '{sub(/^kubernetes_version=/, "", $1); print $1}' <<< "${BINARIES}")
  KUBERNETES_BUILD_DATE=$(awk '{sub(/^kubernetes_build_date=/, "", $2); print $2}' <<< "${BINARIES}")
fi
[[ "${KUBERNETES_VERSION:-}" == "${K8S}."* && -n "${KUBERNETES_BUILD_DATE:-}" ]] \
  || fail "No matching binaries found. Set both KUBERNETES_VERSION and KUBERNETES_BUILD_DATE to published values."

# Reuse the repository's scalar HCL defaults without evaluating them as shell code.
DEFAULT_FILES=("${ROOT}/templates/al2023/variables-default.pkrvars.hcl")
if [[ -f "${ROOT}/templates/al2023/variables-${K8S}.pkrvars.hcl" ]]; then
  DEFAULT_FILES+=("${ROOT}/templates/al2023/variables-${K8S}.pkrvars.hcl")
fi
jq -Rn '[inputs | capture("^\\s*(?<key>[a-z_0-9]+)\\s*=\\s*\"(?<value>[^\"]*)\"\\s*$")?] | from_entries' \
  "${DEFAULT_FILES[@]}" \
  | jq --arg region "${REGION}" --arg version "${KUBERNETES_VERSION}" \
    --arg date "${KUBERNETES_BUILD_DATE}" --arg bucket "${ARTIFACT_BUCKET}" --arg prefix "${PREFIX}" \
    '. + {aws_region:$region, kubernetes_version:$version, kubernetes_build_date:$date,
           artifact_bucket:$bucket, artifact_prefix:$prefix,
           enable_accelerator:"", enable_efa:"false", enable_fips:"false"}' > "${WORK}/build-config.json"

if [[ -z "${SOURCE_AMI_ID:-}" ]]; then
  SOURCE_FILTER=$(jq -r '.source_ami_filter_name | sub("al2023-ami-minimal-"; "al2023-ami-")' "${WORK}/build-config.json")
  SOURCE_AMI_ID=$(aws ec2 describe-images --owners amazon \
    --filters "Name=name,Values=${SOURCE_FILTER}" \
    "Name=architecture,Values=${ARCH}" "Name=state,Values=available" \
    "Name=root-device-type,Values=ebs" "Name=virtualization-type,Values=hvm" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)
fi
[[ -n "${SOURCE_AMI_ID}" && "${SOURCE_AMI_ID}" != None ]] || fail "No source AMI found."
ROOT_DEVICE=$(aws ec2 describe-images --image-ids "${SOURCE_AMI_ID}" \
  --query 'Images[0].RootDeviceName' --output text)
[[ "${ROOT_DEVICE}" == /dev/* ]] || fail "Source AMI has no root device."

if [[ -z "${INSTANCE_PROFILE}" ]]; then
  jq -n '{Version:"2012-10-17", Statement:[{Effect:"Allow",
    Principal:{Service:"ec2.amazonaws.com"}, Action:"sts:AssumeRole"}]}' > "${WORK}/trust.json"
  aws iam create-role --role-name "${RUN_ID}" \
    --assume-role-policy-document "file://${WORK}/trust.json" > /dev/null
  ROLE_CREATED=true
  aws iam attach-role-policy --role-name "${RUN_ID}" --policy-arn "${SSM_POLICY_ARN}"
  ROLE_ATTACHED=true
  jq -n --arg resource "arn:${PARTITION}:s3:::${ARTIFACT_BUCKET}/${PREFIX}/*" \
    --arg bucket "arn:${PARTITION}:s3:::${ARTIFACT_BUCKET}" \
    '{Version:"2012-10-17", Statement:[{Effect:"Allow",
      Action:["s3:GetObject","s3:PutObject"], Resource:$resource},
      {Effect:"Allow", Action:["s3:GetBucketLocation"], Resource:$bucket}]}' > "${WORK}/policy.json"
  aws iam put-role-policy --role-name "${RUN_ID}" --policy-name BuildArtifacts \
    --policy-document "file://${WORK}/policy.json"
  POLICY_ATTACHED=true
  aws iam create-instance-profile --instance-profile-name "${RUN_ID}" > /dev/null
  PROFILE_CREATED=true
  aws iam add-role-to-instance-profile --instance-profile-name "${RUN_ID}" --role-name "${RUN_ID}"
  PROFILE_ROLE_ATTACHED=true
  INSTANCE_PROFILE="${RUN_ID}"
  echo "Waiting for temporary IAM instance profile propagation..."
  sleep 30
fi

tar --exclude=nodeadm/_bin --exclude=nodeadm/_output -czf "${WORK}/source.tar.gz" \
  -C "${ROOT}" templates/al2023/runtime templates/al2023/helpers templates/al2023/provisioners \
  nodeadm log-collector-script/linux hack/ssm-build-instance.sh \
  -C "${WORK}" build-config.json
aws s3 cp "${WORK}/source.tar.gz" "s3://${ARTIFACT_BUCKET}/${PREFIX}/source.tar.gz" --sse AES256
ARCHIVE_UPLOADED=true

jq -n --arg image "${SOURCE_AMI_ID}" --arg type "${INSTANCE_TYPE}" \
  --arg subnet "${SUBNET_ID}" --arg sg "${SECURITY_GROUP_ID}" --arg profile "${INSTANCE_PROFILE}" \
  --arg name "${RUN_ID}" --arg device "${ROOT_DEVICE}" --arg kms "${KMS_KEY_ID:-}" \
  '{ImageId:$image, InstanceType:$type, MinCount:1, MaxCount:1, ClientToken:$name,
    InstanceInitiatedShutdownBehavior:"stop",
    IamInstanceProfile:{Name:$profile},
    MetadataOptions:{HttpTokens:"required", HttpEndpoint:"enabled"},
    NetworkInterfaces:[{DeviceIndex:0, SubnetId:$subnet, Groups:[$sg], AssociatePublicIpAddress:false}],
    BlockDeviceMappings:[{DeviceName:$device, Ebs:({VolumeSize:30, VolumeType:"gp3",
      Encrypted:true, DeleteOnTermination:true} + if $kms == "" then {} else {KmsKeyId:$kms} end)}],
    TagSpecifications:[{ResourceType:"instance", Tags:[{Key:"Name",Value:$name}]}]}' > "${WORK}/launch.json"
INSTANCE_ID=$(aws ec2 run-instances --cli-input-json "file://${WORK}/launch.json" \
  --query 'Instances[0].InstanceId' --output text)
echo "Builder: ${INSTANCE_ID}; logs: s3://${ARTIFACT_BUCKET}/${PREFIX}/"
aws ec2 wait instance-running --instance-ids "${INSTANCE_ID}"

DEADLINE=$((SECONDS + 900))
while :; do
  STATUS=$(aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=${INSTANCE_ID}" \
    --query 'InstanceInformationList[0].PingStatus' --output text)
  [[ "${STATUS}" == Online ]] && break
  ((SECONDS < DEADLINE)) || fail "Builder did not register with SSM within 15 minutes."
  sleep 10
done

run_command() {
  local stage=$1 status deadline
  COMMAND_ID=$(aws ssm send-command --instance-ids "${INSTANCE_ID}" \
    --document-name AWS-RunShellScript --parameters "file://${WORK}/parameters.json" \
    --timeout-seconds 600 --output-s3-bucket-name "${ARTIFACT_BUCKET}" \
    --output-s3-key-prefix "${PREFIX}/${stage}" --query 'Command.CommandId' --output text)
  echo "SSM ${stage}: ${COMMAND_ID}"
  deadline=$((SECONDS + SSM_TIMEOUT_SECONDS + 600))
  while :; do
    status=$(aws ssm list-command-invocations --command-id "${COMMAND_ID}" \
      --instance-id "${INSTANCE_ID}" --query 'CommandInvocations[0].Status' --output text)
    case "${status}" in
      Success)
        COMMAND_ID=""
        return
        ;;
      Pending | InProgress | Delayed | None) ;;
      *)
        aws ssm get-command-invocation --command-id "${COMMAND_ID}" --instance-id "${INSTANCE_ID}"
        fail "SSM ${stage} failed: ${status}. See S3 command logs."
        ;;
    esac
    ((SECONDS < deadline)) || fail "Timed out waiting for SSM ${stage}."
    sleep 10
  done
}

jq -n --arg uri "s3://${ARTIFACT_BUCKET}/${PREFIX}/source.tar.gz" \
  --arg region "${REGION}" --arg timeout "${SSM_TIMEOUT_SECONDS}" \
  '{executionTimeout:[$timeout], commands:[
    "set -eu",
    "cloud-init status --wait",
    "dnf install -y awscli jq tar gzip",
    "install -d -m 0700 /opt/eks-ami-ssm",
    ("aws --region " + ($region|@sh) + " s3 cp " + ($uri|@sh) + " /opt/eks-ami-ssm/source.tar.gz"),
    "tar -xzf /opt/eks-ami-ssm/source.tar.gz -C /opt/eks-ami-ssm",
    "bash /opt/eks-ami-ssm/hack/ssm-build-instance.sh provision"
  ]}' > "${WORK}/parameters.json"
run_command provision
aws s3 cp "s3://${ARTIFACT_BUCKET}/${PREFIX}/version-info.json" "./${AMI_NAME}-version-info.json"

jq -n '{executionTimeout:["120"], commands:[
  "set -eu",
  "systemd-run --unit=eks-ami-ssm-finalize --on-active=60s /usr/bin/bash /opt/eks-ami-ssm/hack/ssm-build-instance.sh finalize"
]}' > "${WORK}/parameters.json"
run_command finalize
aws ec2 wait instance-stopped --instance-ids "${INSTANCE_ID}"
AMI_ID=$(aws ec2 create-image --instance-id "${INSTANCE_ID}" --name "${AMI_NAME}" \
  --description "Standard AL2023 EKS ${KUBERNETES_VERSION}; SSM-native build ${RUN_ID}" \
  --query ImageId --output text)
echo "Waiting for AMI ${AMI_ID}. If interrupted, inspect it before retrying."
aws ec2 wait image-available --image-ids "${AMI_ID}"
jq -n --arg ami "${AMI_ID}" --arg region "${REGION}" --arg source "${SOURCE_AMI_ID}" \
  --arg version "${KUBERNETES_VERSION}" --arg date "${KUBERNETES_BUILD_DATE}" \
  --arg logs "s3://${ARTIFACT_BUCKET}/${PREFIX}/" \
  '{ami_id:$ami, region:$region, source_ami_id:$source, kubernetes_version:$version,
    kubernetes_build_date:$date, logs:$logs}' > "./${AMI_NAME}-manifest.json"
echo "AMI available: ${REGION}:${AMI_ID}"
