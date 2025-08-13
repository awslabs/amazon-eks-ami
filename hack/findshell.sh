#!/bin/bash

# Finds shell scripts to run presubmits against.

has_shell_shebang() {
  local file="$1"

  if grep -I -q -z -E '^#!.*(/|env )(bash|sh)' "$file"; then
    return 0
  fi

  return 1
}

dir=$1
find "$dir" -type f -print0 | while IFS= read -r -d '' file; do

  if [[ "$file" == *"nodeadm/vendor"* ]]; then
    continue
  fi

  if [[ "$file" == *".git/hooks"* ]]; then
    continue
  fi

  if [[ "$file" == *.sh ]] || has_shell_shebang "$file"; then
    echo "$file"
  fi
done
