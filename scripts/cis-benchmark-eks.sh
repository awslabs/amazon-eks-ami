#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

echo "1 - control plane configuration"
echo "[not scored] - not applicable for worker node"

echo "2 - control plane configuration"
echo "[not scored] - not applicable for worker node"

echo "3.1.1 - ensure that the kubeconfig file permissions are set to 644 or more restrictive"
chmod 644 /var/lib/kubelet/kubeconfig

echo "3.1.2 - ensure that the kubelet kubeconfig file ownership is set to root:root"
chown root:root /var/lib/kubelet/kubeconfig

echo "3.1.3 - ensure that the kubelet configuration file permissions are set to 644 or more restrictive"
chmod 644 /etc/kubernetes/kubelet/kubelet-config.json

echo "3.1.4 - ensure that the kubelet configuration file ownership is set to root:root"
chown root:root /etc/kubernetes/kubelet/kubelet-config.json

echo "3.2 - kubelet"
echo "[not scored] - configuration already meets this requirement"
