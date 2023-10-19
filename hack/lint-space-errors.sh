#!/usr/bin/env bash

cd $(dirname $0)/..

# `git apply|diff` can check for space errors, with the core implementation being `git diff-tree`
# this tool compares two trees, generally used to find errors in proposed changes
# we want to check the entire existing tree, so we compare HEAD against an empty tree
git diff-tree --check $(git hash-object -t tree /dev/null) HEAD
