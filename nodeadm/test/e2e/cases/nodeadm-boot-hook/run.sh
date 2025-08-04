#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

nodeadm-internal boot-hook

assert::files-equal /run/systemd/network/80-ec2.network.d/10-eks_primary_eni_only.conf expected-10-eks_primary_eni_only.conf
