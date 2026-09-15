#!/usr/bin/env bash

set -x
set -o errexit
set -o pipefail
set -o nounset

NVIDIA_TREE_ROOT="${NVIDIA_TREE_ROOT:-/opt/nvidia}"
readonly TREE="${NVIDIA_TREE_ROOT}/current"

if ! FLAVOR="$(cat "${TREE}/.driver-flavor")"; then
  echo >&2 "install-packages: no ${TREE}/.driver-flavor"
  exit 1
fi
readonly FLAVOR

readonly FLAVOR_SUBTREE="${TREE}/flavors/${FLAVOR}"

if ! TREE_VERSION="$(cat "${TREE}/.version")"; then
  echo >&2 "install-packages: no ${TREE}/.version"
  exit 1
fi
readonly TREE_VERSION
# .version is the fully resolved version (e.g. 580.65.06), but dnf module streams
# are keyed on the major only (e.g. 580-open).
readonly TREE_MAJOR_VERSION="${TREE_VERSION%%.*}"

shopt -s nullglob # the GRID flavor has no specific RPMs to expand to
readonly RPMS_TO_REGISTER=("${TREE}"/.rpms/*.rpm "${FLAVOR_SUBTREE}"/.rpms/*.rpm)
shopt -u nullglob
if ((${#RPMS_TO_REGISTER[@]} > 0)); then
  rpm -i --justdb --noscripts --nodeps --nodigest --nosignature "${RPMS_TO_REGISTER[@]}"
fi

# enable the correct NVIDIA repo module stream for the chosen driver version
# TODO: consider selecting the {ver}-dkms stream for the proprietary driver
sed -i "s/DRIVER_TREE_VERSION_PLACEHOLDER/${TREE_MAJOR_VERSION}-open/g" /etc/dnf/modules.d/nvidia-driver.module
