#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.31.0

# trigger the creation of cache in config-phase
nodeadm init --skip run --config-source file://config.yaml --config-cache /run/eks/nodeadm/config.json
assert::json-files-equal <(jq .spec /run/eks/nodeadm/config.json) cached-config-1.json

# assert that nodeadm works with an existing cache. we dont need any phase to go
# with this because the parsing happens first.
nodeadm init --skip config,run --config-cache /run/eks/nodeadm/config.json

# trigger changes by writing out a new drop-in
mkdir -p /etc/eks/nodeadm.d/
cat << EOF > /etc/eks/nodeadm.d/test.yaml
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  containerd:
    config: |
      version = 2

      [grpc]
      address = "/run/foo/foo.sock"

      [plugins."io.containerd.grpc.v1.cri".containerd]
      discard_unpacked_layers = false
EOF

# assert that nodeadm should generate a new cache config.
nodeadm init --skip config,run --config-source file://config.yaml,file:///etc/eks/nodeadm.d --config-cache /run/eks/nodeadm/config.json
assert::json-files-equal <(jq .spec /run/eks/nodeadm/config.json) cached-config-2.json
