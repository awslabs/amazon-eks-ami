#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::networkctl
wait::dbus-ready

mkdir -p /mock/config

NETWORKCTL_MOCK_LIST_FILE="/mock/config/networkctl-list.json"
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

START_TIME=$(date +%s)

nodeadm-internal boot-hook &
NODEADM_PID=$!

NOW=$(date +%s)
while [[ "$((NOW - START_TIME))" -le "120" ]]; do
  if ! ps -p "$NODEADM_PID" > /dev/null; then
    if [[ $((NOW - START_TIME)) -lt "60" ]]; then
      echo "nodeadm-boot-hook should have reconciled for at least a minute but exited prematurely!"
      exit 1
    else
      echo "nodeadm exited"
      exit 0
    fi
  fi
  sleep 1
  NOW=$(date +%s)
done

if kill -0 "$NODEADM_PID" &> /dev/null; then
  echo "nodeadm-boot-hook hung for more than 2 minutes!"
  exit 1
fi
