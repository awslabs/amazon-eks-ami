#!/usr/bin/env bash

# Verifies the OSManagedNoManageENIs feature gate: an ENI tagged
# node.k8s.amazonaws.com/no_manage=true is configured by nodeadm via
# systemd-networkd instead of being left unmanaged.
#
# The broker decision is interface-agnostic, so the primary interface stands in
# for the secondary ENI. The harness pins moto's MAC/instance-id to the metadata
# mock's values so the resolver's mac-address + attachment.instance-id lookup
# resolves against it.

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

interface=$(awk '$2 == "00000000" {print $1}' /proc/net/route)
instance_id=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId' --output text)
eni_id=$(aws ec2 describe-instances --query 'Reservations[0].Instances[0].NetworkInterfaces[0].NetworkInterfaceId' --output text)

# Simulate that nodeadm's run phase completed and the feature gate is enabled.
mkdir -p /run/nodeadm
touch /run/nodeadm/init
touch /run/nodeadm/os-managed-no-manage-enis

no_manage_tag="Key=node.k8s.amazonaws.com/no_manage,Value=true"

# Recomputes the decision from scratch (the cache is permanent per interface) and
# asserts both the cached manager and whether a systemd-networkd config was
# rendered. Usage: assert::resolves-to <manager> <managed|unmanaged>
function assert::resolves-to() {
  rm -rf /etc/eks/nodeadm/udev-net-manager
  nodeadm-internal udev-net-manager --action add --interface "$interface"
  assert::file-contains /etc/eks/nodeadm/udev-net-manager/$instance_id/$interface "$1"
  if [ "$2" = "managed" ]; then
    assert::file-contains /run/systemd/network/70-eks-$interface.network "PermanentMACAddress"
  else
    assert::file-not-exists /run/systemd/network/70-eks-$interface.network
  fi
  nodeadm-internal udev-net-manager --action remove --interface "$interface"
}

# --- positive case: ENI tagged no_manage -> nodeadm manages it via systemd ---
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
assert::resolves-to "io.systemd.Network" managed

# --- negative case: same ENI without the tag -> deferred to the VPC CNI ---
aws ec2 delete-tags --resources "$eni_id" --tags "$no_manage_tag"
assert::resolves-to "cni" unmanaged

# --- guard: with the feature marker absent, no EC2 call is made and the ENI is
# deferred to the VPC CNI even though it is tagged no_manage. ---
rm -f /run/nodeadm/os-managed-no-manage-enis
aws ec2 create-tags --resources "$eni_id" --tags "$no_manage_tag"
assert::resolves-to "cni" unmanaged
