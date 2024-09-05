#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.27.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml

assert::file-contains /etc/eks/kubelet/environment '--v=5 --node-labels=foo=bar,foo2=baz --register-with-taints=foo=bar:NoSchedule$'
assert::file-contains /etc/eks/kubelet/environment '--hostname-override=i-1234567890abcdef0'
