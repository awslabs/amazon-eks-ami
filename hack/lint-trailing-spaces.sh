#!/usr/bin/env bash

cd $(dirname $0)/..
git diff-tree --check $(git hash-object -t tree /dev/null) HEAD
