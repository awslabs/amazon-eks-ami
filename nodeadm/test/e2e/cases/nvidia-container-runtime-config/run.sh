#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.32.0
wait::dbus-ready

# skipped when the NVIDIA container runtime is not installed
nodeadm init --skip run --config-source file://config.yaml
assert::file-not-exists /etc/nvidia-container-runtime/config.toml

# simulate an NVIDIA AMI
touch /usr/bin/nvidia-container-runtime
mkdir -p /etc/nvidia-container-runtime
cp existing-config.toml /etc/nvidia-container-runtime/config.toml

# left untouched when no config is provided
nodeadm init --skip run --config-source file://config-without-nvidia-container-runtime.yaml
assert::files-equal /etc/nvidia-container-runtime/config.toml existing-config.toml
assert::file-not-exists /etc/nvidia-container-runtime/.config.toml.orig

# merged over the original, which is saved as .config.toml.orig
nodeadm init --skip run --config-source file://config.yaml
assert::files-equal /etc/nvidia-container-runtime/config.toml expected-config.toml
assert::files-equal /etc/nvidia-container-runtime/.config.toml.orig existing-config.toml

# keys removed from the config revert to their original values
nodeadm init --skip run --config-source file://config-reduced.yaml
assert::files-equal /etc/nvidia-container-runtime/config.toml expected-config-reduced.toml

# removing the config restores the original file and deletes the saved copy
nodeadm init --skip run --config-source file://config-without-nvidia-container-runtime.yaml
assert::files-equal /etc/nvidia-container-runtime/config.toml existing-config.toml
assert::file-not-exists /etc/nvidia-container-runtime/.config.toml.orig
