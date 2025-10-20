#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready

# setup initial networkctl mock interface status
mock::networkctl
mock::set-link-state "eth0" "pending"
mock::set-link-state "eth1" "pending"
mock::set-link-state "lo" "pending"

function mock-states() {
  declare -a POSSIBLE_STATES=(
    "missing"
    "off"
    "no-carrier"
    "dormant"
    "degraded-carrier"
    "carrier"
    "degraded"
    "enslaved"
    "routable"
    "pending"
    "initialized"
    "configuring"
    "configured"
    "unmanaged"
    "failed"
    "linger"
  )
  # test all invalid combinations
  for PRIMARY_STATE in "${POSSIBLE_STATES[@]}"; do
    if [[ "$PRIMARY_STATE" == "configured" ]]; then
      continue
    fi
    mock::set-link-state "eth0" "$PRIMARY_STATE"
    for SECONDARY_STATE in "${POSSIBLE_STATES[@]}"; do
      if [[ "$SECONDARY_STATE" == "unmanaged" ]]; then
        continue
      fi
      mock::set-link-state "eth1" "$SECONDARY_STATE"
      mock::set-link-state "lo" "$SECONDARY_STATE"
    done
    # some wait time larger than the boot hook's reconcile time
    # to make it likely that the state is actually caught
    sleep 0.1
  done
}

mkdir -p /etc/eks/nodeadm/udev-net-manager/i-1234567890abcdef0/

(
  mock-states
  # end with primary and secondary configured.
  mock::set-link-state "eth0" "configured"
  mock::set-link-state "eth1" "configured"
  mock::set-link-state "lo" "unmanaged"
) &
# setup eth1 as a secondary interface that was attached on boot and should be
# managed by systemd.
echo "io.systemd.Network" > /etc/eks/nodeadm/udev-net-manager/i-1234567890abcdef0/eth1
nodeadm-internal boot-hook
assert::json-files-equal expected-interface-eth1-managed-state.json <(networkctl list --json=pretty)

(
  mock-states
  # end with primary configured and secondary not.
  mock::set-link-state "eth0" "configured"
  mock::set-link-state "eth1" "unmanaged"
  mock::set-link-state "lo" "unmanaged"
) &
# setup eth1 as a secondary interface that was attached after boot and cached
# as managed by the cni.
echo "cni" > /etc/eks/nodeadm/udev-net-manager/i-1234567890abcdef0/eth1
nodeadm-internal boot-hook
assert::json-files-equal expected-interface-eth1-unmanaged-state.json <(networkctl list --json=pretty)
