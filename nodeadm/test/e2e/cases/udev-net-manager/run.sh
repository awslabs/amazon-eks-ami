#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::imds
wait::dbus-ready

# hack to get the primary interface name without an net utils. the assumptions
# is that the mac address set for the docker container will match the primary
# interface, so this lets us test the setup without knowing the interface naming
# strategy.
interface=$(awk '$2 == "00000000" {print $1}' /proc/net/route)

nodeadm-internal udev-net-manager --action add --interface $interface

assert::files-equal /run/systemd/network/70-eks-$interface.network 70-eks.network

nodeadm-internal udev-net-manager --action remove --interface $interface
