#!/usr/bin/env bash

set -o errexit

cd "$(dirname $0)/../nodeadm"
make generate
if ! git diff --exit-code .; then
  echo "ERROR: nodeadm generated code is out of date. Please run make generate and commit the changes."
  exit 1
fi
