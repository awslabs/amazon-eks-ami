#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.27.0
wait::dbus-ready

# this test covers cases where the user wants to utilize `reservedSystemCPUs`,
# but per docs `reservedSystemCPUs` is not compatible with the nodeadm default
# behavior to set `systemReservedCgroup` and `kubeReservedCgroup`
#
# see: https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/

nodeadm init --skip run --config-source file://config.yaml
assert::json-files-equal /etc/kubernetes/kubelet/config.json expected-kubelet-config.json
# default the name strategy should be EC2PrivateName, use this pattern to assert
assert::file-contains /etc/eks/kubelet/environment '--hostname-override=ip.*ec2.internal'
