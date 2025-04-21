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
sudo rpm --query --all --queryformat '\{"%{NAME}": "%{VERSION}-%{RELEASE}"\}\n' | jq --slurp --sort-keys 'add | {packages:(.)}' > $OUTPUT_FILE

# kernel modules
for modname in $(sudo lsmod | cut -d' ' -f 1 | tail -n +2); do
  MOD_VERSION=$(sudo modinfo ${modname} --field version)
  if [ -n "$MOD_VERSION" ]; then
    echo $(jq ".kernel_modules.${modname} = \"$MOD_VERSION\"" $OUTPUT_FILE) > $OUTPUT_FILE
  fi
done

# binaries
KUBELET_VERSION=$(kubelet --version | awk '{print $2}')
if [ "$?" != 0 ]; then
  echo "unable to get kubelet version"
  exit 1
fi
echo $(jq ".binaries.kubelet = \"$KUBELET_VERSION\"" $OUTPUT_FILE) > $OUTPUT_FILE

CLI_VERSION=$(aws --version | awk '{print $1}' | cut -d '/' -f 2)
if [ "$?" != 0 ]; then
  echo "unable to get aws cli version"
  exit 1
fi
echo $(jq ".binaries.awscli = \"$CLI_VERSION\"" $OUTPUT_FILE) > $OUTPUT_FILE

# cached images
if systemctl is-active --quiet containerd; then
  echo $(jq ".images = [ $(sudo ctr -n k8s.io image ls -q | cut -d'/' -f2- | sort | uniq | grep -v 'sha256' | xargs -r printf "\"%s\"," | sed 's/,$//') ]" $OUTPUT_FILE) > $OUTPUT_FILE
elif [ "${CACHE_CONTAINER_IMAGES:-}" = "true" ]; then
  echo "containerd must be active to generate version info for cached images"
  exit 1
fi
