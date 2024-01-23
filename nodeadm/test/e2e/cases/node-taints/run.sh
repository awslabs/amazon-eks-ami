#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::imds
mock::kubelet 1.27.0
wait::dbus-ready

nodeadm init --skip run --config-source file://config.yaml

assert::file-contains /etc/eks/kubelet/environment "--register-with-taints=foo=:NoSchedule,foo2=baz:NoSchedule"
