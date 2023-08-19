#!/usr/bin/env bash

if git_status=$("${git[@]}" status --porcelain 2>/dev/null) && [[ -z ${git_status} ]]; then
  BOOTSTRAP_GIT_TREE_STATE="clean"
else
  BOOTSTRAP_GIT_TREE_STATE="dirty"
fi

BOOTSTRAP_GIT_TREE_REF=$(git rev-parse --short HEAD)
BOOTSTRAP_GIT_TREE_BRANCH=$(git branch --show-current)

echo "$BOOTSTRAP_GIT_TREE_BRANCH-$BOOTSTRAP_GIT_TREE_REF-$BOOTSTRAP_GIT_TREE_STATE"
