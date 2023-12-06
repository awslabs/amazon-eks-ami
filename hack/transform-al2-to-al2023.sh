#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

if [[ -z "${PACKER_TEMPLATE_FILE:-}" ]]; then
  echo "PACKER_TEMPLATE_FILE must be set." >&2
  exit 1
fi
if [[ -z "${PACKER_DEFAULT_VARIABLE_FILE:-}" ]]; then
  echo "PACKER_DEFAULT_VARIABLE_FILE must be set." >&2
  exit 1
fi

# rsa keys are not supported in al2023, switch to ed25519
# delete the upgrade kernel provisioner as we don't need it for al2023
cat "${PACKER_TEMPLATE_FILE}" \
  | jq '._comment = "All template variables are enumerated here; and most variables have a default value defined in eks-worker-al2023-variables.json"' \
  | jq '.variables.temporary_key_pair_type = "ed25519"' \
  | jq 'del(.provisioners[5])' \
  | jq 'del(.provisioners[5])' \
  | jq 'del(.provisioners[5])' \
    > "${PACKER_TEMPLATE_FILE/al2/al2023}"

# use newer versions of containerd and runc, do not install docker
# use al2023 6.1 minimal image
cat "${PACKER_DEFAULT_VARIABLE_FILE}" \
  | jq '.ami_component_description = "(k8s: {{ user `kubernetes_version` }}, containerd: {{ user `containerd_version` }})"' \
  | jq '.ami_description = "EKS-optimized Kubernetes node based on Amazon Linux 2023"' \
  | jq '.containerd_version = "*" | .runc_version = "*" | .docker_version = "" ' \
  | jq '.source_ami_filter_name = "al2023-ami-minimal-2023.*-kernel-6.1-x86_64"' \
  | jq '.volume_type = "gp3"' \
    > "${PACKER_DEFAULT_VARIABLE_FILE/al2/al2023}"
