#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

if [ "$#" -ne 4 ]; then
  echo "usage: $0 KUBERNETES_MINOR_VERSION AWS_REGION BINARY_BUCKET_REGION BINARY_BUCKET_NAME"
  exit 1
fi

MINOR_VERSION="${1}"
AWS_REGION="${2}"
BINARY_BUCKET_REGION="${3}"
BINARY_BUCKET_NAME="${4}"

# pass in the --no-sign-request flag if crossing partitions from a us-gov region to a non us-gov region
NO_SIGN_REQUEST=""
if [[ "${AWS_REGION}" == *"us-gov"* ]] && [[ "${BINARY_BUCKET_REGION}" != *"us-gov"* ]]; then
  NO_SIGN_REQUEST="--no-sign-request"
fi

# retrieve the available "VERSION/BUILD_DATE" prefixes (e.g. "1.28.1/2023-09-14")
# from the binary object keys, sorted in descending semver order, and pick the first one
LATEST_BINARIES=$(aws s3api list-objects-v2 "${NO_SIGN_REQUEST}" --region "${BINARY_BUCKET_REGION}" --bucket "${BINARY_BUCKET_NAME}" --prefix "${MINOR_VERSION}" --query 'Contents[*].[Key]' --output text | grep linux | cut -d'/' -f-2 | sort -Vru | head -n1)

if [ "${LATEST_BINARIES}" == "None" ]; then
  echo >&2 "No binaries available for minor version: ${MINOR_VERSION}"
  exit 1
fi

LATEST_VERSION=$(echo "${LATEST_BINARIES}" | cut -d'/' -f1)
LATEST_BUILD_DATE=$(echo "${LATEST_BINARIES}" | cut -d'/' -f2)

echo "kubernetes_version=${LATEST_VERSION} kubernetes_build_date=${LATEST_BUILD_DATE}"
