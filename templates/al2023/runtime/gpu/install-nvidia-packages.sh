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

shopt -s nullglob # the GRID flavor has no specific RPMs to expand to
readonly RPMS_TO_REGISTER=("${TREE}"/.rpms/*.rpm "${FLAVOR_SUBTREE}"/.rpms/*.rpm)
shopt -u nullglob
if ((${#RPMS_TO_REGISTER[@]} > 0)); then
  rpm -i --justdb --noscripts --nodeps --nodigest --nosignature "${RPMS_TO_REGISTER[@]}"
fi
