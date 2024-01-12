#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

BINARIES=(
  "nodeadm"
)

PLATFORMS=(
  "linux/amd64"
  "linux/arm64"
)

if [[ $# -eq 0 ]]; then
  echo "usage: $0 DIST_DIR (GO_FLAGS...)"
  exit 1
fi

DIST_DIR="$1"
shift
DIST_BIN_DIR="$DIST_DIR/bin"

rm -rf $DIST_BIN_DIR
mkdir -p $DIST_BIN_DIR

for BINARY in "${BINARIES[@]}"; do
  for PLATFORM in "${PLATFORMS[@]}"; do
    PLATFORM_PARTS=(${PLATFORM//\// })
    GOOS=${PLATFORM_PARTS[0]}
    GOARCH=${PLATFORM_PARTS[1]}
    OUTPUT_DIR="$DIST_BIN_DIR/$GOOS/$GOARCH"
    mkdir -p $OUTPUT_DIR
    GOOS=$GOOS GOARCH=$GOARCH go build -o $OUTPUT_DIR/$BINARY "$@" cmd/$BINARY/main.go
  done
done
