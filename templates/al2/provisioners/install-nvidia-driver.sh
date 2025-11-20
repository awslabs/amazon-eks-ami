#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o xtrace

if [ "$ENABLE_ACCELERATOR" != "nvidia" ]; then
  exit 0
fi

##### UTILITY FUNCTIONS ######

# utility function for pulling rpms from an S3 bucket
function rpm_install() {
  local RPMS=("$@")
  echo "pulling and installing rpms:(${RPMS[*]}) from s3 bucket: (${BINARY_BUCKET_NAME}) in region: (${BINARY_BUCKET_REGION})"
  for RPM in "${RPMS[@]}"; do
    # we're pulling these rpms from the same bucket as the binaries, because those
    # can be replicated up to highside easily
    aws s3 cp --region ${BINARY_BUCKET_REGION} s3://${BINARY_BUCKET_NAME}/rpms/${RPM} ${WORKING_DIR}/${RPM}
    sudo yum localinstall -y ${WORKING_DIR}/${RPM}
    # the WORKING_DIR will be cleaned up at the end of the build
    rm ${WORKING_DIR}/${RPM}
  done
}

# utility function to resolve the latest driver version from a driver prefix
function resolve_latest_driver_version_from_json() {
  local DRIVER_PREFIX="$1"
  local JSON_URL=""
  local TEMP_JSON_FILE="/tmp/nvidia_releases.json"
  DRIVER_PREFIX=$(echo "${DRIVER_PREFIX}" | sed 's/\*$//')
  if [[ $AWS_REGION == cn-* ]]; then
    DOMAIN="nvidia.cn"
  else
    DOMAIN="nvidia.com"
  fi

  JSON_URL="https://docs.${DOMAIN}/datacenter/tesla/drivers/releases.json"

  echo "Resolving latest NVIDIA driver version for prefix: ${DRIVER_PREFIX}" >&2
  echo "Using JSON URL: ${JSON_URL}" >&2

  if ! curl -s -o "${TEMP_JSON_FILE}" "${JSON_URL}"; then
    echo "Failed to download NVIDIA driver releases JSON. Unable to resolve runfile from the provided prefix: ${DRIVER_PREFIX}" >&2
    echo "${DRIVER_PREFIX}"
    exit 1
  fi

  local LATEST_VERSION
  LATEST_VERSION=$(jq -e -r --arg prefix "${DRIVER_PREFIX}" '.[$prefix].driver_info[0].release_version' "${TEMP_JSON_FILE}")

  if [ -z "${LATEST_VERSION}" ] || [ "${LATEST_VERSION}" = "null" ]; then
    echo "No matching driver version found for prefix ${DRIVER_PREFIX}" >&2
    echo "${DRIVER_PREFIX}"
    return 1
  fi

  echo "Resolved latest driver version: ${LATEST_VERSION}" >&2
  echo "${LATEST_VERSION}"
  rm -f "${TEMP_JSON_FILE}"
}

# A utility function to ensure that nvidia-open-supported-devices.txt is correctly generated
validate_nvidia_supported_devices_file() {
  local KMOD_MAJOR_VERSION="$1"
  # add some quick validations to ensure that the build fails if
  GENERATED_SUPPORTED_DEVICES_FILE="/etc/eks/nvidia-open-supported-devices-${KMOD_MAJOR_VERSION}.txt"
  if [ ! -s "$GENERATED_SUPPORTED_DEVICES_FILE" ]; then
    echo "ERROR: Generated supported devices file is empty or missing"
    exit 1
  fi

  # check to ensure that the file is not empty
  TOTAL_SUPPORTED_GPU_ENTRY_COUNT=$(grep -c "^0x" "$GENERATED_SUPPORTED_DEVICES_FILE" 2> /dev/null || echo "0")
  echo "Count of GPU entries in ${GENERATED_SUPPORTED_DEVICES_FILE}: ${TOTAL_SUPPORTED_GPU_ENTRY_COUNT}"
  if [ "$TOTAL_SUPPORTED_GPU_ENTRY_COUNT" -eq 0 ]; then
    echo "ERROR: No GPU entries found in generated nvidia-open-supported-devices.txt file"
    exit 1
  fi

  # check to ensure that the format of the file is correct
  if ! grep -E "^0x[0-9A-F]{4} .+" "$GENERATED_SUPPORTED_DEVICES_FILE" > /dev/null; then
    echo "ERROR: Generated file contains malformed entries"
    echo "Expected format: '0xXXXX GPU_NAME'"
    exit 1
  fi
}

# function that downloads the nvidia driver .run file and then builds and archives the kernel modules
function install_nvidia_driver() {
  local NVIDIA_RUNFILE_URL=""
  local EXTRACT_DIR="${WORKING_DIR}/NVIDIA-Linux-extract"
  local NVIDIA_RUNFILE_NAME="NVIDIA-Linux-${NVIDIA_ARCH}-${RESOLVED_DRIVER_VERSION}.run"
  echo "Installing NVIDIA driver ${RESOLVED_DRIVER_VERSION} for ${NVIDIA_ARCH} using runfile method"

  if gpu-ami-util is-isolated-partition || [[ $AWS_REGION == cn-* ]]; then
    NVIDIA_DRIVER_MAJOR_VERSION=$(echo $RESOLVED_DRIVER_VERSION | cut -d. -f1)
    NVIDIA_RUNFILE_URL="s3://${BINARY_BUCKET_NAME}/bin/nvidia-runfiles/${NVIDIA_DRIVER_MAJOR_VERSION}/${NVIDIA_RUNFILE_NAME}"
    echo "S3 download URL: ${NVIDIA_RUNFILE_URL}"
    aws s3 cp --region ${BINARY_BUCKET_REGION} "${NVIDIA_RUNFILE_URL}" "${WORKING_DIR}/${NVIDIA_RUNFILE_NAME}"
  else
    DOMAIN="us.download.nvidia.com"
    NVIDIA_RUNFILE_URL="https://${DOMAIN}/tesla/${RESOLVED_DRIVER_VERSION}/${NVIDIA_RUNFILE_NAME}"

    echo "Download URL: ${NVIDIA_RUNFILE_URL}"
    echo "Downloading NVIDIA driver runfile..."
    wget -O "${WORKING_DIR}/${NVIDIA_RUNFILE_NAME}" "${NVIDIA_RUNFILE_URL}"
  fi

  chmod +x "${WORKING_DIR}/${NVIDIA_RUNFILE_NAME}"

  echo "Extracting NVIDIA driver runfile..."
  sudo "${WORKING_DIR}/${NVIDIA_RUNFILE_NAME}" --extract-only --target "${EXTRACT_DIR}"

  pushd "${EXTRACT_DIR}"

  # install proprietary kernel modules
  echo "Installing NVIDIA driver with proprietary kernel modules..."
  sudo ./nvidia-installer \
    --kernel-module-type proprietary \
    --dkms \
    --silent || sudo cat /var/log/nvidia-installer.log

  # archive and remove proprietary modules
  echo "Archiving proprietary kernel modules..."
  sudo kmod-util archive nvidia
  sudo kmod-util remove nvidia

  # The DKMS package name differs between the RPM and the dkms.conf in the OSS kmod sources
  # TODO: can be removed if this is merged: https://github.com/NVIDIA/open-gpu-kernel-modules/pull/567
  echo "Modifying DKMS configuration for open-source modules..."
  sudo sed -i 's/PACKAGE_NAME="nvidia"/PACKAGE_NAME="nvidia-open"/g' kernel-open/dkms.conf

  # install open-source kernel modules
  echo "Installing NVIDIA driver with open-source kernel modules..."
  sudo ./nvidia-installer \
    --kernel-module-type open \
    --dkms \
    --silent \
    --kernel-module-source-dir=nvidia-open-${RESOLVED_DRIVER_VERSION} || sudo cat /var/log/nvidia-installer.log

  KMOD_MAJOR_VERSION=$(sudo kmod-util module-version nvidia-open | cut -d. -f1)
  # assemble the list of supported nvidia devices for the open kernel modules
  echo -e "# This file was generated from supported-gpus/supported-gpus.json\n$(sed -e 's/^/# /g' supported-gpus/LICENSE)" \
    | sudo tee -a /etc/eks/nvidia-open-supported-devices-$KMOD_MAJOR_VERSION.txt

  cat supported-gpus/supported-gpus.json \
    | jq -r '.chips[] | select(.features[] | contains("kernelopen")) | "\(.devid) \(.name)"' \
    | sort -u \
    | sudo tee -a /etc/eks/nvidia-open-supported-devices-$KMOD_MAJOR_VERSION.txt

  validate_nvidia_supported_devices_file $KMOD_MAJOR_VERSION

  # archive and remove open-source modules
  echo "Archiving open-source kernel modules..."
  sudo kmod-util archive nvidia-open
  sudo kmod-util remove nvidia-open

  # uninstall everything before doing a clean install of just the user-space components
  echo "Uninstalling previous driver components..."
  sudo ./nvidia-installer --uninstall --silent
  sudo rm -rf /usr/src/nvidia*
  sudo rm -rf /usr/src/nvidia-open*

  # install user-space components only
  echo "Installing NVIDIA driver user-space components..."
  sudo ./nvidia-installer \
    --no-kernel-modules \
    --silent

  popd
  sudo rm -rf "${EXTRACT_DIR}"
  # removing the downloaded runfile
  sudo rm "${WORKING_DIR}/${NVIDIA_RUNFILE_NAME}"
}

function create_nvidia_persistenced_service() {
  # The nvidia-persistenced rpms for 570 drivers contain pre-install scripts that set up
  # the necessary group and user for nvidia-persistenced service. Ex. rpm -qp --scripts nvidia-persistenced-latest-dkms-550.163.01-1.el7.x86_64.rpm
  # When we install drivers from the run files, nvidia-persistenced binaries are created but the corresponding .service file and user groups need to be created
  # Ref: https://download.nvidia.com/XFree86/Linux-x86_64/570.195.03/README/nvidia-persistenced.html
  if [ -f /usr/bin/nvidia-persistenced ]; then
    echo "Setting up nvidia-persistenced service..."

    # mirror the RPM preinstall scriptlet setup
    sudo groupadd -r nvidia-persistenced
    sudo useradd -r -g nvidia-persistenced -d /var/run/nvidia-persistenced -s /sbin/nologin \
      -c "NVIDIA persistent software state" nvidia-persistenced

    sudo tee /usr/lib/systemd/system/nvidia-persistenced.service > /dev/null << 'EOF'
[Unit]
Description=NVIDIA Persistence Daemon
After=syslog.target

[Service]
Type=forking
PIDFile=/var/run/nvidia-persistenced/nvidia-persistenced.pid
Restart=always
ExecStart=/usr/bin/nvidia-persistenced --verbose
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced/*
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable nvidia-persistenced

    echo "nvidia-persistenced service set up successfully."
  else
    echo "Error: nvidia-persistenced binary not found!"
    exit 1
  fi

}

function install_nvidia_fabric_manager() {
  if gpu-ami-util is-isolated-partition; then
    # For isolated regions, we install nvidia-fabric-manager from the s3 buckets
    rpm_install "nvidia-fabric-manager-${RESOLVED_DRIVER_VERSION}-1.x86_64.rpm"
  else
    # For standard and china regions, the fabric manager is installed from rhel8 repo
    sudo yum install -y "nvidia-fabric-manager-${RESOLVED_DRIVER_VERSION}"

    # Exclude nvidia-fabricmanager packages from cuda-rhel8.repo to prevent version conflicts during yum updates
    echo "exclude=nvidia-fabricmanager*" | sudo tee -a /etc/yum.repos.d/cuda-rhel8.repo
  fi
  sudo systemctl enable nvidia-fabricmanager

}

function install_nvidia_container_toolkit() {
  if gpu-ami-util is-isolated-partition || [[ $AWS_REGION == cn-* ]]; then
    # dependency of libnvidia-container-tools
    rpm_install "libnvidia-container1-1.17.8-1.x86_64.rpm"
    # dependencies of nvidia-container-toolkit
    rpm_install "nvidia-container-toolkit-base-1.17.8-1.x86_64.rpm" "libnvidia-container-tools-1.17.8-1.x86_64.rpm"
    rpm_install "nvidia-container-toolkit-1.17.8-1.x86_64.rpm"
  else
    # Install nvidia container toolkit, based on
    # https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-yum-or-dnf
    sudo yum-config-manager --add-repo=https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
    sudo yum --setopt=timeout=60 --setopt=retries=10 --setopt=retrydelay=10 install -y nvidia-container-toolkit
  fi
}

#############################

if [[ "${NVIDIA_DRIVER_VERSION}" == *"."*"."* ]]; then
  # if the full driver version is provided, no need to resolve it from the releases.json
  RESOLVED_DRIVER_VERSION="${NVIDIA_DRIVER_VERSION}"
  echo "Provided driver version: ${RESOLVED_DRIVER_VERSION}"
else
  RESOLVED_DRIVER_VERSION=$(resolve_latest_driver_version_from_json "${NVIDIA_DRIVER_VERSION}")
fi

NVIDIA_ARCH=$(uname -m)

# installing required dependencies for building kernel modules and runfile installation
# The kernel* versionlocks are added by install-worker.sh provisioner in the upstream:
# https://github.com/awslabs/amazon-eks-ami/blob/main/templates/al2/provisioners/install-worker.sh#L59
sudo yum install -y "kernel-devel-$(uname -r)" "kernel-headers-$(uname -r)" gcc make dkms jq

if gpu-ami-util is-isolated-partition; then
  # these are required in order to build kmod-nvidia-open-dkms, and would
  # normally be available from epel but that isn't reachable in ADC
  rpm_install "opencl-filesystem-1.0-5.el7.noarch.rpm" "ocl-icd-2.2.12-1.el7.x86_64.rpm"
else
  sudo amazon-linux-extras install epel -y

  if [[ $AWS_REGION == cn-* ]]; then
    DOMAIN="nvidia.cn"
  else
    DOMAIN="nvidia.com"
  fi

  # Add NVIDIA REHL8 repo for nvidia-fabricmanager
  sudo yum-config-manager --add-repo=https://developer.download.${DOMAIN}/compute/cuda/repos/rhel8/${NVIDIA_ARCH}/cuda-rhel8.repo

fi

# The driver setup will happen in five steps:
# 1. install the nvidia driver: we install the open-source, closed-source kernel modules as well as the user-space modules. We archive the kernel modules.
# 2. install the nvidia fabric manager
# 3. set up nvidia-persistenced service and enable it
# 4. install nvidia container toolkit libraries

install_nvidia_driver
install_nvidia_fabric_manager
create_nvidia_persistenced_service
install_nvidia_container_toolkit

# We versionlock the NVIDIA packages, because our archived kernel modules will only work with the accompanying userland packages on the same version
sudo yum versionlock \
  nvidia-* libnvidia-*

mkdir -p /etc/eks
# writing latest installed driver version to a text file to provide it to nvidia-kmod-load.sh
# that determines if the instance supports an open-source nvidia-driver
echo "Writing driver version to /etc/eks/nvidia-latest-driver-version.txt"
mkdir -p /etc/eks
echo "${RESOLVED_DRIVER_VERSION}" | sudo tee /etc/eks/nvidia-latest-driver-version.txt

# Show the NVIDIA EULA at startup
sudo mv ${WORKING_DIR}/accelerator/nvidia-eula.sh /etc/eks/
sudo mv ${WORKING_DIR}/accelerator/nvidia-eula.service /etc/systemd/system/

# Add a systemd unit that will load NVIDIA kernel modules on applicable instance types
sudo mv ${WORKING_DIR}/accelerator/nvidia-kmod-load.service /etc/systemd/system/
sudo mv ${WORKING_DIR}/accelerator/nvidia-kmod-load.sh /etc/eks/
sudo systemctl daemon-reload
sudo systemctl enable nvidia-kmod-load

# Add a bootstrap helper that will configure containerd appropriately
sudo mv ${WORKING_DIR}/accelerator/bootstrap-gpu.sh /etc/eks/
sudo mv ${WORKING_DIR}/accelerator/bootstrap-gpu-nvidia.sh /etc/eks/
