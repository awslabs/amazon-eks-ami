#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.31.0

nodeadm init --skip run -c file://config.yaml

assert::files-equal /run/systemd/resolved.conf.d/40-eks.conf expected-resolved.conf
