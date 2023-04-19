#!/usr/bin/env bash

# generates a JSON file containing version information for the software in this AMI

set -o errexit
set -o pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_FILE"
  exit 1
fi

OUTPUT_FILE="$1"

# packages
sudo rpm --query --all --queryformat '\{"%{NAME}": "%{VERSION}-%{RELEASE}"\}\n' | jq --slurp --sort-keys 'add | {packages:(.)}' > "${OUTPUT_FILE}"

# binaries
KUBELET_VERSION=$(kubelet --version | cut -d' ' -f2)
echo "$(jq ".binaries.kubelet = \"${KUBELET_VERSION}\"" "${OUTPUT_FILE}")" > "${OUTPUT_FILE}"

AWSCLI_VERSION=$(aws --version | cut -d' ' -f1 | cut -d'/' -f2)
echo "$(jq ".binaries.awscli = \"${AWSCLI_VERSION}\"" "${OUTPUT_FILE}")" > "${OUTPUT_FILE}"

# cached images
echo "$(jq ".images = [ $(sudo ctr -n k8s.io image ls -q | cut -d'/' -f2- | sort | uniq | grep -v 'sha256' | xargs -r printf "\"%s\"," | sed 's/,$//') ]" "${OUTPUT_FILE}")" > "${OUTPUT_FILE}"
