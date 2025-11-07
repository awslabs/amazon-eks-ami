#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

# This test checks if nodeadm's config and run phase are able to properly route ec2 traffic through an http proxy.
# The testing container image contains the following servers:
# 1. AWS_ENDPOINT_URL: Mocks the AWS EC2 API responses running at 0.0.0.0:5000
# 2. AWS_EC2_METADATA_SERVICE_ENDPOINT: Mocks IMDS running at localhost:1338
# 3. proxy server: Can be started as needed and is running at 8080.
#
# To enable http proxy on AL2023 AMIs pass HTTP_PRPOXY and HTTPS_PROXY in NodeConfig as shown below:
#
# ---
# apiVersion: node.eks.aws/v1alpha1
# kind: NodeConfig
# spec:
#   instance:
#     environment:
#       default:
#         HTTP_PROXY: "http://localhost:8080"
#         HTTPS_PROXY: "https://localhost:8080"
#   cluster:
#     apiServerEndpoint: https://example.com
#     certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=
#     cidr: 10.100.0.0/16
#     name: my-cluster
#
# The above userdata is also base64 encoded into `http-proxy-imds-mock.json`
mock::aws http-proxy-imds-mock.json
mock::kubelet 1.27.0
wait::dbus-ready

# When running an e2e test image, the mock API servers use link-local address.
# By default, link-local addresses cannot be routed by a proxy server.
# We set the host to 0.0.0.0 so that ec2 api calls go through the proxy.
export AWS_ENDPOINT_URL=http://0.0.0.0:5000

# Test 1 - Spin up a proxy-server and testing the traffic for nodeadm config phase
echo "Starting HTTP Proxy Server"
python3 /proxy.py --output-path /tmp/nodeadm-config-trafic.log > /tmp/plogs.log &
PROXY_SERVER_PID=$!
echo "PROXY SERVER PID: ${PROXY_SERVER_PID}"
echo "Sleeping for a few seconds to warm the proxy server"
sleep 5

nodeadm init --skip run

kill $PROXY_SERVER_PID
assert::files-equal /tmp/nodeadm-config-trafic.log expected-nodeadm-config-traffic.log

# Test 2 - Spin up a proxy-server and testing the traffic for nodeadm run phase
echo "Starting HTTP Proxy Server"
python3 /proxy.py --output-path /tmp/nodeadm-run-trafic.log > /tmp/plogs.log &
PROXY_SERVER_PID=$!
echo "PROXY SERVER PID: ${PROXY_SERVER_PID}"
echo "Sleeping for a few seconds to warm the proxy server"
sleep 5

nodeadm init --skip config

kill $PROXY_SERVER_PID
assert::files-equal /tmp/nodeadm-run-trafic.log expected-nodeadm-run-traffic.log

# Test 3 - Spin up a proxy-server and testing the traffic for both init and run
echo "Starting HTTP Proxy Server"
python3 /proxy.py --output-path /tmp/nodeadm-trafic.log > /tmp/plogs.log &
PROXY_SERVER_PID=$!
echo "PROXY SERVER PID: ${PROXY_SERVER_PID}"
echo "Sleeping for a few seconds to warm the proxy server"
sleep 5

nodeadm init

kill $PROXY_SERVER_PID
assert::files-equal /tmp/nodeadm-trafic.log expected-nodeadm-traffic.log
