#!/usr/bin/env bash

set -o pipefail
set -o nounset

validate_directory_selinux_contexts() {
  local DIR=$1
  echo "Validating SELinux contexts in $DIR"

  unverified_files=$(matchpathcon -V $DIR/* | grep -v verified)

  if [ -n "$unverified_files" ]; then
    echo "$unverified_files"
    unverified_files_count=$(echo "$unverified_files" | wc -l)
    echo "Validation error: Found $unverified_files_count files with incorrect SELinux context in folder $DIR"
    exit 1
  fi
  echo "Validated SELinux contexts in $DIR"
}

validate_directory_selinux_contexts /usr/bin
