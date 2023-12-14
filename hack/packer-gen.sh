#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

MODE="${1:-}"

usage() {
  echo "usage: $0 (template|variables) { DIMENSIONS }"
}

PACKER_TEMPLATE_DIR="packer"
STAGING_DIR=".staging"

# Consider a path for the output value if it exists
search() {
  if [ -f "$1" ]; then
    OUTPUT_PATH="$1"
  fi
}

# Consider a path for the output value if a source and destination path both
# exist, then merge the two together to create a single file and write it to the
# path of the source data
# $1 - base config
# $2 - patch config
merge() {
  if [ -f "$1" ] && [ -f "$2" ]; then
    merged=$(jq -s '.[0] + .[1]' $1 $2)
    echo "$merged" > $1
    OUTPUT_PATH="$1"
  fi
}

# template mode will take the most nested packer template as the source of truth
# based on the specified dimensions
if [ "$MODE" == "template" ]; then
  FILENAME="eks-worker.json"
  for dim in "${@:2}"; do
    BASE="${BASE+$BASE/}$dim"
    search $PACKER_TEMPLATE_DIR/$BASE/$FILENAME
  done
# variables mode will merge variable definitions from least to most specific
# based on the specified dimensions, then save them to a staging file
elif [ "$MODE" == "variables" ]; then
  FILENAME="eks-worker-variables.json"
  mkdir -p $STAGING_DIR
  rm -f $STAGING_DIR/$FILENAME
  touch $STAGING_DIR/$FILENAME
  for dim in "${@:2}"; do
    BASE="${BASE+$BASE/}$dim"
    merge $STAGING_DIR/$FILENAME $PACKER_TEMPLATE_DIR/$BASE/$FILENAME
  done
# invalid run mode
else
  usage
  exit 1
fi

if [ -z "${OUTPUT_PATH:-}" ]; then
  echo >&2 "No configurations could be found for packer ${MODE} with dimension search order [${*:2}]"
  exit 1
else
  echo $OUTPUT_PATH
fi
