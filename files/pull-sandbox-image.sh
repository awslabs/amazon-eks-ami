#!/usr/bin/env bash
set -euo pipefail

sandbox_image="$(awk -F'[ ="]+' '$1 == "sandbox_image" { print $2 }' /etc/containerd/config.toml)"
/etc/eks/containerd/pull-image.sh "${sandbox_image}"
