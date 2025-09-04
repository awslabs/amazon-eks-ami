#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

################################################################################
### Validate Required Arguments ################################################
################################################################################
validate_env_set() {
  (
    set +o nounset

    if [ -z "${!1}" ]; then
      echo "Packer variable '$1' was not set. Aborting"
      exit 1
    fi
  )
}

validate_env_set HARDENED_IMAGE
validate_env_set WORKING_DIR

################################################################################
### Install/Add Go 1.24 Patch ##################################################
################################################################################

install_go_1.24_patch() {
  cd "${WORKING_DIR}/selinux/go-1.24"
  make -f /usr/share/selinux/devel/Makefile
  sudo semodule -i go-patch.pp
}

################################################################################
### Install/Add Node Exporter Patch ############################################
################################################################################

install_node_exporter_patch() {
  cd "${WORKING_DIR}/selinux/node-exporter"
  make -f /usr/share/selinux/devel/Makefile
  sudo semodule -i node-exporter.pp
}

################################################################################
### Install/Add Required Selinux Policies ######################################
################################################################################

if [[ "$HARDENED_IMAGE" == "true" ]]; then
  sudo chcon -t bin_t /usr/bin/nodeadm && \
  sudo systemctl disable firewalld && \
  sudo yum install container-selinux selinux-policy-devel -y && \
  # Install Go 1.24 Patch that allows for read/write to socket.
  install_go_1.24_patch
  # Install node_exporter patch
  install_node_exporter_patch
fi
