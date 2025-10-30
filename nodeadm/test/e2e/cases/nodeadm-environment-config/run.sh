#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws http-proxy-imds-mock.json
mock::kubelet 1.27.0
wait::dbus-ready

# Test 1 - Basic environment variable configuration
nodeadm init --skip run --config-source file://config-basic-env.yaml
assert::files-equal /etc/systemd/system.conf.d/environment.conf expected-config-basic-env.conf

# Test 2 - Quote escaping in environment variables
nodeadm init --skip run --config-source file://config-quote-escaping.yaml
assert::files-equal /etc/systemd/system.conf.d/environment.conf expected-config-quote-escaping.conf

# Test 3 - Service-specific environment variables
nodeadm init --skip run --config-source file://config-service-specific.yaml
assert::files-equal /etc/systemd/system.conf.d/environment.conf expected-config-service-specific-default.conf
assert::files-equal /etc/systemd/system/kubelet.service.d/environment.conf expected-config-service-specific-kubelet.conf
assert::files-equal /etc/systemd/system/containerd.service.d/environment.conf expected-config-service-specific-containerd.conf

# Test 4 - Service-only environment variables (no default)
rm -f /etc/systemd/system.conf.d/environment.conf
rm -f /etc/systemd/system/kubelet.service.d/environment.conf
rm -f /etc/systemd/system/containerd.service.d/environment.conf

nodeadm init --skip run --config-source file://config-service-only.yaml
# Should NOT create system.conf.d file since no default vars
assert::file-not-exists /etc/systemd/system.conf.d/environment.conf
assert::files-equal /etc/systemd/system/kubelet.service.d/environment.conf expected-config-service-only-kubelet.conf
assert::files-equal /etc/systemd/system/containerd.service.d/environment.conf expected-config-service-only-containerd.conf

# Test 5 - No environment section at all so should not create any config file
rm -f /etc/systemd/system.conf.d/environment.conf
rm -f /etc/systemd/system/kubelet.service.d/environment.conf
rm -f /etc/systemd/system/containerd.service.d/environment.conf

nodeadm init --skip run --config-source file://config-no-env.yaml
assert::file-not-exists /etc/systemd/system.conf.d/environment.conf
assert::file-not-exists /etc/systemd/system/kubelet.service.d/environment.conf
assert::file-not-exists /etc/systemd/system/containerd.service.d/environment.conf

# Test 6 - Empty environment section. Similar to test case 5 but checks if user can pass keys with empty values i.e. {}
rm -f /etc/systemd/system.conf.d/environment.conf
rm -f /etc/systemd/system/kubelet.service.d/environment.conf
rm -f /etc/systemd/system/containerd.service.d/environment.conf

nodeadm init --skip run --config-source file://config-empty-env.yaml
assert::file-not-exists /etc/systemd/system.conf.d/environment.conf
assert::file-not-exists /etc/systemd/system/kubelet.service.d/environment.conf
assert::file-not-exists /etc/systemd/system/containerd.service.d/environment.conf

# Test 7 - Spin up a proxy-server and testing the traffic for nodeadm config phase
echo "Starting HTTP Proxy Server"
python3 /proxy.py --output nodeadm-config-trafic.log > /tmp/plogs.log &
PROXY_SERVER_PID=$!
echo "PROXY SERVER PID: ${PROXY_SERVER_PID}"
echo "Sleeping a few seconds to warm the proxy server"
sleep 5

nodeadm init --skip run

assert::files-equal /tmp/nodeadm-config-trafic.log expected-nodeadm-config-traffic.log
kill $PROXY_SERVER_PID


# Test 8 - Spin up a proxy-server and testing the traffic for nodeadm run phase
echo "Starting HTTP Proxy Server"
python3 /proxy.py --output nodeadm-run-trafic.log > /tmp/plogs.log &
PROXY_SERVER_PID=$!
echo "PROXY SERVER PID: ${PROXY_SERVER_PID}"
echo "Sleeping a few seconds to warm the proxy server"
sleep 5

nodeadm init --skip config

assert::files-equal /tmp/nodeadm-run-trafic.log expected-nodeadm-run-traffic.log
kill $PROXY_SERVER_PID