#!/usr/bin/env bash

if git_status=$("${git[@]}" status --porcelain 2> /dev/null) && [[ -z ${git_status} ]]; then
  NODEADM_GIT_TREE_STATE="clean"
else
  NODEADM_GIT_TREE_STATE="dirty"
fi

NODEADM_GIT_TREE_REF=$(git rev-parse --short HEAD)
NODEADM_GIT_TREE_BRANCH=$(git branch --show-current)

echo "$NODEADM_GIT_TREE_BRANCH-$NODEADM_GIT_TREE_REF-$NODEADM_GIT_TREE_STATE"
