#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

mock::kubelet 1.27.0-eks-5e0fdde
nodeadm init --skip run --config-source file://config.yaml
assert::file-not-contains /etc/kubernetes/kubelet/config.json '"kubeAPIQPS"'
assert::file-not-contains /etc/kubernetes/kubelet/config.json '"kubeAPIBurst"'
