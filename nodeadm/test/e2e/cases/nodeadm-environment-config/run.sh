#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
mock::kubelet 1.34.0
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
