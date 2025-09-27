#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 1 ]; then
  echo >&2 "usage: $0 NVIDIA_DRIVER_MAJOR_VERSION"
  exit 1
fi

cd "$(dirname $0)"

NVIDIA_DRIVER_MAJOR_VERSION="${1}"
FULL_DRIVER_VERSION=$(curl https://docs.nvidia.com/datacenter/tesla/drivers/releases.json | jq -e -r --arg driver_version "${NVIDIA_DRIVER_MAJOR_VERSION}" '.[$driver_version].driver_info[0].release_version')
TEMP_DIR=$(mktemp -d)
RUNFILE_NAME="NVIDIA-Linux-$(uname -m)-${FULL_DRIVER_VERSION}.run"
wget -O "${TEMP_DIR}"/"${RUNFILE_NAME}" "https://us.download.nvidia.com/tesla/${FULL_DRIVER_VERSION}/${RUNFILE_NAME}"
RUNFILE_DIR=$(basename "${RUNFILE_NAME}" | sed s/\.run//g)
SUPPORTED_GPUS_FILE="supported-gpus/supported-gpus.json"

cd "${TEMP_DIR}"

RUNFILE_MAJOR_VERSION=$(sh "${RUNFILE_NAME}" --info | grep Identification | awk '{print $NF}' | cut -d. -f1)
sh "${RUNFILE_NAME}" --extract-only

cd -

ACKNOWLEDGEMENT="# This file was generated from ${SUPPORTED_GPUS_FILE} contained in $(basename "${RUNFILE_NAME}")"

COMMENTED_LICENSE=$(sed -e 's/^/# /g' "${TEMP_DIR}/${RUNFILE_DIR}/supported-gpus/LICENSE" | sed -e 's/^# $/#/g')

OUTPUT_FILE="../templates/al2023/runtime/gpu/nvidia-open-supported-devices-${RUNFILE_MAJOR_VERSION}.txt"

printf '%s\n%s\n' "${ACKNOWLEDGEMENT}" "${COMMENTED_LICENSE}" \
  | tee "${OUTPUT_FILE}"

cat "${TEMP_DIR}/${RUNFILE_DIR}/${SUPPORTED_GPUS_FILE}" \
  | jq -r '.chips[] | select(.features[] | contains("kernelopen")) | "\(.devid) \(.name)"' \
  | sort -u \
  | tee -a "${OUTPUT_FILE}"
