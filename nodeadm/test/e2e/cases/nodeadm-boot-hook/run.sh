#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::networkctl
wait::dbus-ready

mkdir -p /mock/config

export NETWORKCTL_MOCK_LIST_FILE="/mock/config/networkctl-list.json"

# Start with 2 pending interfaces
jq '.' << EOF > $NETWORKCTL_MOCK_LIST_FILE
{
    "Interfaces": [
        {
            "Name": "eth0",
            "AdministrativeState": "pending"
        },
        {
            "Name": "lo",
            "AdministrativeState": "pending"
        }
    ]
}
EOF

declare -a POSSIBLE_STATES=("missing" "off" "no-carrier" "dormant" "degraded-carrier" "carrier" "degraded" "enslaved" "routable" "pending" "initialized" "configuring" "configured" "unmanaged" "failed" "linger")

(
  # test all invalid combinations
  for PRIMARY_STATE in "${POSSIBLE_STATES[@]}"; do
    if [[ "$PRIMARY_STATE" == "configured" ]]; then
      continue
    fi
    mock::set-link-state "eth0" "$PRIMARY_STATE"
    for SECONDARY_STATE in "${POSSIBLE_STATES[@]}"; do
      if [[ "$PRIMARY_STATE" == "unmanaged" ]]; then
        continue
      fi
      mock::set-link-state "lo" "$SECONDARY_STATE"
    done
    # some wait time larger than the boot hook's reconcile time
    # to make it likely that the state is actually caught
    sleep 0.1
  done

  # set to valid states
  mock::set-link-state "eth0" "configured"
  mock::set-link-state "lo" "unmanaged"
) &

nodeadm-internal boot-hook

ACTUAL_NETWORK_STATE=$(mktemp)
networkctl list --json=pretty > "$ACTUAL_NETWORK_STATE"

EXPECTED_NETWORK_STATE=$(mktemp)
jq '.' << EOF > $EXPECTED_NETWORK_STATE
{
    "Interfaces": [
        {
            "Name": "eth0",
            "AdministrativeState": "configured"
        },
        {
            "Name": "lo",
            "AdministrativeState": "unmanaged"
        }
    ]
}
EOF

assert::files-equal $ACTUAL_NETWORK_STATE $EXPECTED_NETWORK_STATE

EXPECTED_CONFIG_FILE=$(mktemp)
cat << EOF > $EXPECTED_CONFIG_FILE
[Match]
PermanentMACAddress=$(cat /sys/class/net/eth0/address)
EOF

assert::files-equal /run/systemd/network/80-ec2.network.d/10-eks_primary_eni_only.conf $EXPECTED_CONFIG_FILE
