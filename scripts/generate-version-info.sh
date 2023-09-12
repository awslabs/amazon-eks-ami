#!/bin/sh

# generates a JSON file containing version information for the software in this AMI

set -o errexit
set -o pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 OUTPUT_FILE"
  exit 1
fi

OUTPUT_FILE="$1"

# packages
sudo rpm --query --all --queryformat '\{"%{NAME}": "%{VERSION}-%{RELEASE}"\}\n' | jq --slurp --sort-keys 'add | {packages:(.)}' > "$OUTPUT_FILE"

# binaries
echo $(jq ".binaries.kubelet = \"$(kubelet --version | awk '{print $2}')\"" $OUTPUT_FILE) > $OUTPUT_FILE
echo $(jq ".binaries.awscli = \"$(aws --version | awk '{print $1}' | cut -d '/' -f 2)\"" $OUTPUT_FILE) > $OUTPUT_FILE

# cached images
if systemctl is-active --quiet containerd; then
  echo $(jq ".images = [ $(sudo ctr -n k8s.io image ls -q | cut -d'/' -f2- | sort | uniq | grep -v 'sha256' | xargs -r printf "\"%s\"," | sed 's/,$//') ]" $OUTPUT_FILE) > $OUTPUT_FILE
elif [ "${CACHE_CONTAINER_IMAGES}" = "true" ]; then
  echo "containerd must be active to generate version info for cached images"
  exit 1
fi
