#!/usr/bin/env bash

set -o pipefail
set -o nounset

validate_directory_selinux_contexts() {
  local DIR=$1
  echo "Validating SELinux contexts in $DIR"

  # recurse, so files inside subdirectories (e.g. the drop-ins under /etc/systemd/*.conf.d) are covered and not just the subdirectory itself.
  unverified_files=$(find "$DIR" -exec matchpathcon -V {} + | grep -v verified)

  if [ -n "$unverified_files" ]; then
    echo "$unverified_files"
    unverified_files_count=$(echo "$unverified_files" | wc -l)
    echo "Validation error: Found $unverified_files_count files with incorrect SELinux context in folder $DIR"
    exit 1
  fi
  echo "Validated SELinux contexts in $DIR"
}

sudo restorecon -R -v /usr/bin
validate_directory_selinux_contexts /usr/bin

# `cp -rv` of runtime/rootfs does not preserve contexts, so every drop-in we ship (networkd.conf.d,
# network/*.link.d, ...) inherits etc_t from its parent instead of its own expected type.
sudo restorecon -R -v /etc/systemd
validate_directory_selinux_contexts /etc/systemd

sudo restorecon -R -v /etc/eks
validate_directory_selinux_contexts /etc/eks
