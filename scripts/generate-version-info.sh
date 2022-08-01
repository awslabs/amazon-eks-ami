#!/bin/sh

# generates a JSON file containing version information for the software in this AMI

set -o errexit
set -o pipefail

if [ "$#" -ne 1 ]
then
  echo "usage: $0 OUTPUT_FILE"
  exit 1
fi

OUTPUT_FILE="$1"

# packages
yum list installed --quiet | awk '{print $1, $2}' | jq -R 'inputs | split(" ") | {(.[0]):(.[1])}' | jq -s add  | jq '{packages:(.)}' > "$OUTPUT_FILE"

# binaries
echo $(jq ".binaries.kubelet = \"$(kubelet --version | awk '{print $2}')\"" $OUTPUT_FILE) > $OUTPUT_FILE