#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.27.0
wait::dbus-ready

# Test 1 - Basic environment variable configuration
nodeadm init --skip run --config-source file://config-basic-env.yaml
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="DUMMY_VAR=HELLO WORLD"'
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="HTTP_PROXY=http://example-proxy:8080"'
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="HTTPS_PROXY=https://example-proxy:8080"'
assert::file-contains /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="NO_PROXY=localhost,127.0.0.1,169.254.169.254"'

# Test 2 - Quote escaping in environment variables
nodeadm init --skip run --config-source file://config-quote-escaping.yaml
assert::file-contains-literal /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="SIMPLE_VAR=simple value"'
assert::file-contains-literal /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="QUOTED_VAR=value with \"quotes\" inside"'
assert::file-contains-literal /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="BACKSLASH_VAR=value with \\backslash"'

# Test 3 - Service-specific environment variables
nodeadm init --skip run --config-source file://config-service-specific.yaml
# System wide
assert::file-contains-literal /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="HTTP_PROXY=http://default-proxy:8080"'
assert::file-contains-literal /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="HTTPS_PROXY=https://default-proxy:8080"'
assert::file-contains-literal /etc/systemd/system.conf.d/environment.conf 'DefaultEnvironment="NO_PROXY=localhost,127.0.0.1,169.254.169.254"'
# kubelet-specific environment variables
assert::file-contains-literal /etc/systemd/system/kubelet.service.d/environment.conf 'Environment="KUBELET_SPECIFIC_VAR=kubelet-value"'
assert::file-contains-literal /etc/systemd/system/kubelet.service.d/environment.conf 'Environment="HTTP_PROXY=http://kubelet-proxy:8080"'
# containerd-specific environment variables
assert::file-contains-literal /etc/systemd/system/containerd.service.d/environment.conf 'Environment="CONTAINERD_SPECIFIC_VAR=containerd-value"'

# Test 4 - Service-only environment variables (no default)
rm -f /etc/systemd/system.conf.d/environment.conf
rm -f /etc/systemd/system/kubelet.service.d/environment.conf
rm -f /etc/systemd/system/containerd.service.d/environment.conf

nodeadm init --skip run --config-source file://config-service-only.yaml
# Should NOT create system.conf.d file since no default vars
if [ -f /etc/systemd/system.conf.d/environment.conf ]; then
  echo "ERROR: system.conf.d/environment.conf should not exist when no default vars are specified"
  exit 1
fi
assert::file-contains-literal /etc/systemd/system/kubelet.service.d/environment.conf 'Environment="KUBELET_ONLY_VAR=kubelet-only-value"'
assert::file-contains-literal /etc/systemd/system/containerd.service.d/environment.conf 'Environment="CONTAINERD_ONLY_VAR=containerd-only-value"'

# Test 5 - No environment section at all
rm -f /etc/systemd/system.conf.d/environment.conf
rm -f /etc/systemd/system/kubelet.service.d/environment.conf
rm -f /etc/systemd/system/containerd.service.d/environment.conf

nodeadm init --skip run --config-source file://config-no-env.yaml
if [ -f /etc/systemd/system.conf.d/environment.conf ]; then
  echo "ERROR: system.conf.d/environment.conf should not exist when no environment section is specified"
  exit 1
fi
if [ -f /etc/systemd/system/kubelet.service.d/environment.conf ]; then
  echo "ERROR: kubelet environment.conf should not exist when no environment section is specified"
  exit 1
fi
if [ -f /etc/systemd/system/containerd.service.d/environment.conf ]; then
  echo "ERROR: containerd environment.conf should not exist when no environment section is specified"
  exit 1
fi

# Test 6 - Empty environment section
rm -f /etc/systemd/system.conf.d/environment.conf
rm -f /etc/systemd/system/kubelet.service.d/environment.conf
rm -f /etc/systemd/system/containerd.service.d/environment.conf

nodeadm init --skip run --config-source file://config-empty-env.yaml
if [ -f /etc/systemd/system.conf.d/environment.conf ]; then
  echo "ERROR: system.conf.d/environment.conf should not exist when environment section is empty"
  exit 1
fi
if [ -f /etc/systemd/system/kubelet.service.d/environment.conf ]; then
  echo "ERROR: kubelet environment.conf should not exist when environment section is empty"
  exit 1
fi
if [ -f /etc/systemd/system/containerd.service.d/environment.conf ]; then
  echo "ERROR: containerd environment.conf should not exist when environment section is empty"
  exit 1
fi
