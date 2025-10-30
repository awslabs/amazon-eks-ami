#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws http-proxy-imds-mock.json
mock::kubelet 1.27.0
wait::dbus-ready

# Test 1 - Spin up a proxy-server and testing the traffic for nodeadm config phase
echo "Starting HTTP Proxy Server"
python3 /proxy.py --output nodeadm-config-trafic.log > /tmp/plogs.log &
PROXY_SERVER_PID=$!
echo "PROXY SERVER PID: ${PROXY_SERVER_PID}"
echo "Sleeping a few seconds to warm the proxy server"
sleep 5

nodeadm init --skip run

assert::files-equal /tmp/nodeadm-config-trafic.log expected-nodeadm-config-traffic.log
kill $PROXY_SERVER_PID

# Test 2 - Spin up a proxy-server and testing the traffic for nodeadm run phase
echo "Starting HTTP Proxy Server"
python3 /proxy.py --output nodeadm-run-trafic.log > /tmp/plogs.log &
PROXY_SERVER_PID=$!
echo "PROXY SERVER PID: ${PROXY_SERVER_PID}"
echo "Sleeping a few seconds to warm the proxy server"
sleep 5

nodeadm init --skip config

assert::files-equal /tmp/nodeadm-run-trafic.log expected-nodeadm-run-traffic.log
kill $PROXY_SERVER_PID
