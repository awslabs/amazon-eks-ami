#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::imds
wait::dbus-ready

mock::kubelet 1.22.0
nodeadm init --skip run --config-source file://config.yaml
assert::file-contains /etc/eks/kubelet/environment "--register-with-taints=foo=:NoSchedule,foo2=baz:NoSchedule"

# Kubelet 1.23 version change added support for register-with-taints in kubelet config
# https://github.com/kubernetes/kubernetes/blob/7bb00356f06332e63a9f06acd42f1bdd8fc559d6/CHANGELOG/CHANGELOG-1.23.md?plain=1#L2401

mock::kubelet 1.23.0
nodeadm init --skip run --config-source file://config.yaml
assert::file-contains /etc/eks/kubelet/environment "--register-with-taints=foo=:NoSchedule,foo2=baz:NoSchedule"

mock::kubelet 1.28.0
nodeadm init --skip run --config-source file://config.yaml
assert::file-contains /etc/eks/kubelet/environment "--register-with-taints=foo=:NoSchedule,foo2=baz:NoSchedule"
