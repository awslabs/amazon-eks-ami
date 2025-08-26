#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.27.0
wait::dbus-ready

# Test 1 - Basic environment variable configuration"
nodeadm init --skip run --config-source file://config-basic-env.yaml
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="DUMMY_VAR=HELLO WORLD"'
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="HTTP_PROXY=http://example-proxy:8080"'
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="HTTPS_PROXY=https://example-proxy:8080"'
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="NO_PROXY=localhost,127.0.0.1,169.254.169.254"'
