#!/usr/bin/env bash

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TEST_ROOT=$(mktemp -d)
SCENARIOS=(success existing-profile arm64-minor command-failure finalize-failure iam-denial launch-denial image-failure cleanup-failure missing-input)
cleanup() {
  rm -f "${TEST_ROOT}/bin/aws" "${TEST_ROOT}/bin/tar" "${TEST_ROOT}/bin/sleep"
  local scenario
  for scenario in "${SCENARIOS[@]}"; do
    rm -f "${TEST_ROOT}/${scenario}/calls" "${TEST_ROOT}/${scenario}/stdout" \
      "${TEST_ROOT}/${scenario}/stderr" "${TEST_ROOT}/${scenario}/launch.json" \
      "${TEST_ROOT}/${scenario}/config.json" "${TEST_ROOT}/${scenario}/provision.json" \
      "${TEST_ROOT}/${scenario}/finalize.json" "${TEST_ROOT}/${scenario}/policy.json" \
      "${TEST_ROOT}/${scenario}/test-ami-manifest.json" \
      "${TEST_ROOT}/${scenario}/test-ami-version-info.json"
    rmdir "${TEST_ROOT}/${scenario}"
  done
  rmdir "${TEST_ROOT}/bin" "${TEST_ROOT}"
}
trap cleanup EXIT
mkdir "${TEST_ROOT}/bin"

cat > "${TEST_ROOT}/bin/aws" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == --region && "$2" == ca-central-1 ]]
shift 2
printf '%s\n' "$*" >> "${TEST_STATE}/calls"
operation="$1 $2"
shift 2
arg() {
  local key=$1
  shift
  while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "${key}" ]]; then printf '%s' "$2"; return; fi
    shift
  done
  return 1
}
case "${operation}" in
  "sts get-caller-identity") echo '{"Account":"123456789012","Arn":"arn:aws:iam::123456789012:role/test"}' ;;
  "s3api head-bucket") ;;
  "iam create-role")
    if [[ "${SCENARIO}" == iam-denial ]]; then echo 'AccessDenied: iam:CreateRole' >&2; exit 42; fi
    ;;
  "iam put-role-policy")
    path=$(arg --policy-document "$@")
    cp "${path#file://}" "${TEST_STATE}/policy.json"
    ;;
  "iam attach-role-policy" | "iam create-instance-profile" | "iam add-role-to-instance-profile" | \
    "iam remove-role-from-instance-profile" | "iam delete-instance-profile" | \
    "iam delete-role-policy" | "iam detach-role-policy") ;;
  "iam delete-role")
    if [[ "${SCENARIO}" == cleanup-failure ]]; then echo 'AccessDenied: iam:DeleteRole' >&2; exit 45; fi
    ;;
  "ec2 describe-images")
    if [[ " $* " == *" --image-ids "* ]]; then echo /dev/xvda; else echo ami-source; fi
    ;;
  "ec2 run-instances")
    path=$(arg --cli-input-json "$@")
    cp "${path#file://}" "${TEST_STATE}/launch.json"
    if [[ "${SCENARIO}" == launch-denial ]]; then echo 'UnauthorizedOperation: ec2:RunInstances' >&2; exit 43; fi
    echo i-builder
    ;;
  "ec2 wait")
    if [[ "$1" == image-available && "${SCENARIO}" == image-failure ]]; then exit 44; fi
    ;;
  "ec2 terminate-instances") ;;
  "ec2 create-image") echo ami-result ;;
  "ssm describe-instance-information") echo Online ;;
  "ssm send-command")
    path=$(arg --parameters "$@")
    if grep -q systemd-run "${path#file://}"; then
      cp "${path#file://}" "${TEST_STATE}/finalize.json"
      echo command-finalize
    else
      cp "${path#file://}" "${TEST_STATE}/provision.json"
      echo command-provision
    fi
    ;;
  "ssm list-command-invocations")
    if [[ "${SCENARIO}" == command-failure ||
      ("${SCENARIO}" == finalize-failure && " $* " == *" command-finalize "*) ]]; then
      echo Failed
    else
      echo Success
    fi
    ;;
  "ssm get-command-invocation") echo '{"Status":"Failed","StandardErrorContent":"fixture provisioning failure"}' ;;
  "ssm cancel-command") ;;
  "s3 cp")
    if [[ "$1" == s3://* ]]; then echo '{}' > "$2"; fi
    ;;
  "s3 rm") ;;
  *) echo "Unexpected AWS operation: ${operation}" >&2; exit 99 ;;
esac
EOF

# Do not archive real repository payloads or contact AWS in this test.
cat > "${TEST_ROOT}/bin/tar" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == --exclude=nodeadm/_bin && "$2" == --exclude=nodeadm/_output && "$3" == -czf ]]
touch "$4"
cp "$(dirname "$4")/build-config.json" "${TEST_STATE}/config.json"
EOF
cat > "${TEST_ROOT}/bin/sleep" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${TEST_ROOT}/bin/"*

export PATH="${TEST_ROOT}/bin:${PATH}"
export REGION=ca-central-1 ARCH=x86_64 K8S=1.37
export KUBERNETES_VERSION=1.37.1 KUBERNETES_BUILD_DATE=2026-10-01
export SUBNET_ID=subnet-test SECURITY_GROUP_ID=sg-test ARTIFACT_BUCKET=private-test-bucket AMI_NAME=test-ami
unset INSTANCE_PROFILE SOURCE_AMI_ID KMS_KEY_ID INSTANCE_TYPE SSM_TIMEOUT_SECONDS

assert_no_call() {
  if grep -Ei "$1" "${TEST_STATE}/calls"; then
    echo "Unexpected API call matching: $1" >&2
    exit 1
  fi
}

for SCENARIO in "${SCENARIOS[@]}"; do
  export SCENARIO
  export TEST_STATE="${TEST_ROOT}/${SCENARIO}"
  mkdir "${TEST_STATE}"
  export ARCH=x86_64 K8S=1.37 KUBERNETES_VERSION=1.37.1
  if [[ "${SCENARIO}" == arm64-minor ]]; then
    export ARCH=arm64 K8S=1.35 KUBERNETES_VERSION=1.35.1
  fi
  if [[ "${SCENARIO}" == existing-profile ]]; then
    export INSTANCE_PROFILE=approved-profile
  else
    unset INSTANCE_PROFILE
  fi
  result=0
  (
    cd "${TEST_STATE}"
    if [[ "${SCENARIO}" == missing-input ]]; then unset SUBNET_ID; fi
    bash "${ROOT}/hack/build-ssm.sh"
  ) > "${TEST_STATE}/stdout" 2> "${TEST_STATE}/stderr" || result=$?

  case "${SCENARIO}" in
    success | existing-profile | arm64-minor)
      [[ "${result}" == 0 ]]
      jq -e --arg version "${KUBERNETES_VERSION}" '.ami_id == "ami-result" and .kubernetes_version == $version
        and .source_ami_id == "ami-source" and .region == "ca-central-1"' \
        "${TEST_STATE}/test-ami-manifest.json" > /dev/null
      jq -e 'has("KeyName") == false and has("UserData") == false
        and .NetworkInterfaces[0].AssociatePublicIpAddress == false
        and .NetworkInterfaces[0].Groups == ["sg-test"]
        and .InstanceInitiatedShutdownBehavior == "stop"
        and .MetadataOptions.HttpTokens == "required"
        and .BlockDeviceMappings[0].Ebs.Encrypted == true
        and .BlockDeviceMappings[0].Ebs.DeleteOnTermination == true' \
        "${TEST_STATE}/launch.json" > /dev/null
      jq -e '.enable_efa == "false" and .enable_fips == "false" and .enable_accelerator == ""
        and .containerd_version == "2.*" and .kubernetes_build_date == "2026-10-01"
        and .nodeadm_build_image != null' "${TEST_STATE}/config.json" > /dev/null
      jq -e '.commands[-1] == "bash /opt/eks-ami-ssm/hack/ssm-build-instance.sh provision"
        and (.commands | index("dnf install -y awscli jq tar gzip") != null)
        and .executionTimeout == ["14400"]' "${TEST_STATE}/provision.json" > /dev/null
      grep -q 'ec2 terminate-instances' "${TEST_STATE}/calls"
      grep -q 's3 rm .*source.tar.gz' "${TEST_STATE}/calls"
      if [[ "${SCENARIO}" != existing-profile ]]; then
        jq -e '.Statement[0].Action == ["s3:GetObject","s3:PutObject"]
          and (.Statement[0].Resource | startswith("arn:aws:s3:::private-test-bucket/eks-ami-ssm-"))' \
          "${TEST_STATE}/policy.json" > /dev/null
        grep -q 'iam delete-role ' "${TEST_STATE}/calls"
        grep -q 'iam delete-instance-profile ' "${TEST_STATE}/calls"
        if [[ "${SCENARIO}" == arm64-minor ]]; then
          jq -e '.InstanceType == "m6g.xlarge"' "${TEST_STATE}/launch.json" > /dev/null
          grep -q 'Name=name,Values=al2023-ami-2023.\*-kernel-6.12-\* Name=architecture,Values=arm64' "${TEST_STATE}/calls"
        fi
      else
        assert_no_call '^iam '
        jq -e '.IamInstanceProfile.Name == "approved-profile"' "${TEST_STATE}/launch.json" > /dev/null
      fi
      ;;
    missing-input)
      [[ "${result}" != 0 ]]
      [[ ! -e "${TEST_STATE}/calls" ]]
      grep -q 'Set SUBNET_ID' "${TEST_STATE}/stderr"
      ;;
    cleanup-failure)
      [[ "${result}" != 0 ]]
      [[ -e "${TEST_STATE}/test-ami-manifest.json" ]]
      grep -q 'WARNING: Could not delete role' "${TEST_STATE}/stderr"
      grep -q 's3 rm .*source.tar.gz' "${TEST_STATE}/calls"
      ;;
    *)
      [[ "${result}" != 0 ]]
      [[ ! -e "${TEST_STATE}/test-ami-manifest.json" ]]
      if [[ "${SCENARIO}" != iam-denial ]]; then
        grep -q 'iam delete-role ' "${TEST_STATE}/calls"
        grep -q 's3 rm .*source.tar.gz' "${TEST_STATE}/calls"
      fi
      if [[ "${SCENARIO}" == command-failure || "${SCENARIO}" == finalize-failure ]]; then
        grep -q 'ssm cancel-command' "${TEST_STATE}/calls"
        assert_no_call 'ec2 create-image'
      fi
      if [[ "${SCENARIO}" == command-failure || "${SCENARIO}" == finalize-failure || "${SCENARIO}" == image-failure ]]; then
        grep -q 'ec2 terminate-instances' "${TEST_STATE}/calls"
      fi
      ;;
  esac
  if [[ -e "${TEST_STATE}/calls" ]]; then
    assert_no_call 'create-key-pair|import-key-pair|authorize-security-group-ingress|start-session'
  fi
  echo "PASS: ${SCENARIO}"
done
