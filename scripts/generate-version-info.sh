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
