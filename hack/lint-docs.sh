#!/usr/bin/env bash

set -o errexit

cd $(dirname $0)

./generate-template-variable-doc.py
if ! git diff --exit-code ../doc/usage/; then
  echo "ERROR: AMI template documentation is out of date. Please run hack/generate-template-variable-doc.py and commit the changes."
  exit 1
fi

cd ../nodeadm
make generate-doc
if ! git diff --exit-code doc/; then
  echo "ERROR: nodeadm documentation is out of date. Please run 'make generate-doc' and commit the changes."
  exit 1
fi
cd -

./mkdocs.sh build --strict
