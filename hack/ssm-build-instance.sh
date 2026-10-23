#!/usr/bin/env bash

set -euo pipefail

ROOT=/opt/eks-ami-ssm
WORKING_DIR="${ROOT}/worker"
export WORKING_DIR

[[ "${EUID}" == 0 ]] || {
  echo "Run this script as root on the disposable builder." >&2
  exit 1
}
[[ -f "${ROOT}/build-config.json" ]] || {
  echo "Missing builder payload at ${ROOT}; refusing to modify this host." >&2
  exit 1
}

finalize() {
  # Stop SSM before removing its per-instance identity and downloaded command payloads.
  systemctl stop amazon-ssm-agent
  rm -f /etc/resolv.conf
  rm -rf /var/lib/amazon/ssm /var/log/amazon/ssm /opt/eks-ami-ssm
  rm -f /root/.bash_history /home/ec2-user/.bash_history
  systemctl poweroff
}

provision() {
  cd "${ROOT}"
  jq -r 'to_entries[] | "\(.key | ascii_upcase)=\(.value)"' build-config.json > build-config.env
  while IFS= read -r setting; do
    export "${setting?}"
  done < build-config.env
  export BUILD_IMAGE="${NODEADM_BUILD_IMAGE}"
  export PROJECT_DIR="${WORKING_DIR}/nodeadm"
  export NVIDIA_REPOSITORY="${NVIDIA_REPOSITORY_URL}"
  export EC2_GRID_DRIVER_S3_BUCKET="${NVIDIA_GRID_RUNFILE_BUCKET_NAME}"

  mkdir -p "${WORKING_DIR}"/{rootfs,bin,gpu,helpers,nodeadm,log-collector-script}
  cp -a templates/al2023/runtime/rootfs/. "${WORKING_DIR}/rootfs/"
  cp -a templates/al2023/runtime/bin/. "${WORKING_DIR}/bin/"
  cp -a templates/al2023/runtime/gpu/. "${WORKING_DIR}/gpu/"
  cp -a templates/al2023/helpers/. "${WORKING_DIR}/helpers/"
  cp -a nodeadm/. "${PROJECT_DIR}/"
  cp -a log-collector-script/linux/. "${WORKING_DIR}/log-collector-script/"
  mkdir -p /etc/eks/log-collector-script
  cp "${WORKING_DIR}/log-collector-script/eks-log-collector.sh" /etc/eks/log-collector-script/
  cp -rv "${WORKING_DIR}/rootfs/"* /
  chmod -R a+x "${WORKING_DIR}/bin/" "${WORKING_DIR}/gpu/"
  cp -rv "${WORKING_DIR}/bin/"* /usr/bin/

  cd "${WORKING_DIR}"
  local script
  for script in set-clocksource enable-fips limit-c-states install-worker install-nodeadm \
    cache-pause-container install-neuron-driver install-nvidia-drivers install-efa \
    distrust-ca-certificates; do
    echo "Running ${script}"
    bash "${ROOT}/templates/al2023/provisioners/${script}.sh"
  done
  bash "${ROOT}/templates/al2023/provisioners/generate-version-info.sh" "${ROOT}/version-info.json"
  aws --region "${AWS_REGION}" s3 cp "${ROOT}/version-info.json" \
    "s3://${ARTIFACT_BUCKET}/${ARTIFACT_PREFIX}/version-info.json" --sse AES256
  bash "${ROOT}/templates/al2023/provisioners/configure-selinux.sh"
  # Cleanup removes DNS configuration. Restore it only for SSM to report results;
  # finalize removes it again before stopping the instance for image capture.
  cp -L /etc/resolv.conf "${ROOT}/resolv.conf"
  (
    trap 'cp "${ROOT}/resolv.conf" /etc/resolv.conf' EXIT
    bash -e "${ROOT}/templates/al2023/provisioners/cleanup.sh"
    bash "${ROOT}/templates/al2023/provisioners/validate.sh"
  )
  echo "Provisioning, cleanup and validation complete."
}

case "${1:-}" in
  provision) provision ;;
  finalize) finalize ;;
  *)
    echo "Usage: $0 provision|finalize" >&2
    exit 1
    ;;
esac
