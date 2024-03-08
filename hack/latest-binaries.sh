#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset


BUCKET="amazon-eks"
REGION="us-west-2"
PROFILE=""

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--profile)
      PROFILE="$2"
      shift # past argument
      shift # past value
      ;;
    -b|--bucket)
      BUCKET="$2"
      shift 
      shift
      ;;
    -r|--region)
      REGION="$2"
      shift
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

get_latest_binaries() {

  local profile=""

  if [ -n "${PROFILE}" ]; then
    profile="--profile ${PROFILE}"
  fi  
  
  # retrieve the available "VERSION/BUILD_DATE" prefixes (e.g. "1.28.1/2023-09-14")
  # from the binary object keys, sorted in descending semver order, and pick the first one
  LATEST_BINARIES=$(aws s3api list-objects-v2 ${profile} --region "${REGION}" --bucket "${BUCKET}" --prefix "${MINOR_VERSION}" --query 'Contents[*].[Key]' --output text | cut -d'/' -f-2 | sort -Vru | head -n1)

  if [ "${LATEST_BINARIES}" == "None" ]; then
    echo >&2 "No binaries available for minor version: ${MINOR_VERSION}"
    exit 1
  fi

  LATEST_VERSION=$(echo "${LATEST_BINARIES}" | cut -d'/' -f1)
  LATEST_BUILD_DATE=$(echo "${LATEST_BINARIES}" | cut -d'/' -f2)

  echo "kubernetes_version=${LATEST_VERSION} kubernetes_build_date=${LATEST_BUILD_DATE}"

}

if [ "$#" -ne 1 ]; then
  echo "usage: $0 KUBERNETES_MINOR_VERSION"
  exit 1
fi

MINOR_VERSION="${1}"

echo $(get_latest_binaries)



