#!/usr/bin/env bash

set -o errexit
cd $(dirname $0)
./generate-template-variable-doc.py
if ! git diff --exit-code ../doc/USER_GUIDE.md; then
  echo "ERROR: doc/USER_GUIDE.md is out of date. Please run hack/generate-template-variable-doc.py and commit the changes."
  exit 1
fi
./mkdocs.sh build --strict
