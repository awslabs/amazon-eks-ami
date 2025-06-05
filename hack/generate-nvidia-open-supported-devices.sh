#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 1 ]; then
  echo >&2 "usage: $0 NVIDIA_LINUX_RUNFILE"
  echo >&2
  echo >&2 "Download a .run file from: https://www.nvidia.com/en-us/drivers/unix/"
  exit 1
fi

cd $(dirname $0)

RUNFILE="${1}"
RUNFILE_DIR=$(basename "${RUNFILE}" | sed s/\.run//g)
TEMP_DIR=$(mktemp -d)
DEVICE_FILE="devices.txt"
SUPPORTED_GPUS_FILE="supported-gpus/supported-gpus.json"

cp "${RUNFILE}" "${TEMP_DIR}"

cd "${TEMP_DIR}"

RUNFILE_MAJOR_VERSION=$(sh "${RUNFILE}" --info | grep Identification | awk '{print $NF}' | cut -d. -f1)
sh "${RUNFILE}" --extract-only

cd -

cat "${TEMP_DIR}/${RUNFILE_DIR}/${SUPPORTED_GPUS_FILE}" \
  | jq -r '.chips[] | select(.features[] | contains("kernelopen")) | "\(.devid) \(.name)"' \
  | sort -u \
  > "${TEMP_DIR}/${DEVICE_FILE}"

ACKNOWLEDGEMENT="# This file was generated from ${SUPPORTED_GPUS_FILE} contained in $(basename "${RUNFILE}")"

COMMENTED_LICENSE=$(sed -e 's/^/# /g' "${TEMP_DIR}/${RUNFILE_DIR}/supported-gpus/LICENSE")

OUTPUT_FILE="../templates/al2023/runtime/gpu/nvidia-open-supported-devices-${RUNFILE_MAJOR_VERSION}.txt"

printf '%s\n%s\n' "${ACKNOWLEDGEMENT}" "${COMMENTED_LICENSE}" \
  | cat - ${TEMP_DIR}/${DEVICE_FILE} > "${OUTPUT_FILE}"
