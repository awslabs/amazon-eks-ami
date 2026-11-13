#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.35.0

# kubelet has not been started yet, so there should be no warning
nodeadm init --daemon="" --config-source file://config.yaml > /tmp/nodeadm.log 2>&1
assert::file-not-contains /tmp/nodeadm.log "kubelet was started before nodeadm"

# Faking that kubelet.service started kubelet before the run phase
mkdir -p /run/eks/kubelet/ && touch /run/eks/kubelet/started

nodeadm init --daemon="" --config-source file://config.yaml > /tmp/nodeadm.log 2>&1
assert::file-contains /tmp/nodeadm.log "kubelet was started before nodeadm"
