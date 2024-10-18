#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

mock::kubelet 1.28.0
nodeadm init --skip run --config-source file://config.yaml
assert::file-contains /etc/eks/kubelet/environment '--pod-infra-container-image=localhost/kubernetes/pause'

mock::kubelet 1.29.0
nodeadm init --skip run --config-source file://config.yaml
assert::file-not-contains /etc/eks/kubelet/environment 'pod-infra-container-image'
