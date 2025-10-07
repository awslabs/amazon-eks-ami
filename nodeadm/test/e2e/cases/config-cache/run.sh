#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

source /helpers.sh

mock::aws
wait::dbus-ready
mock::kubelet 1.31.0

# trigger the creation of cache in config-phase using imds
nodeadm init --skip run --config-cache /run/eks/nodeadm/config.json
assert::json-files-equal <(jq .spec /run/eks/nodeadm/config.json) cached-config-1.json

# assert that nodeadm does not crash and should load an existing cache. we dont
# need any phase to go with this because the parsing happens first.
nodeadm init --skip config,run --config-cache /run/eks/nodeadm/config.json
assert::json-files-equal <(jq .spec /run/eks/nodeadm/config.json) cached-config-1.json

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

# assert that if nodeadm tries to use the drop-in directory without the base
# config from IMDS, then the verification should fail even if we have a cache.
if nodeadm init --skip config,run --config-source file:///etc/eks/nodeadm.d --config-cache /run/eks/nodeadm/config.json; then
  echo "running nodeadm with only a partial drop-in NodeConfig as the source should not work!"
  exit 1
fi

# with a fixed config-source, assert that nodeadm generates a new cache config.
nodeadm init --skip config,run --config-source imds://user-data,file:///etc/eks/nodeadm.d --config-cache /run/eks/nodeadm/config.json
assert::json-files-equal <(jq .spec /run/eks/nodeadm/config.json) cached-config-2.json

# cleanup the drop-ins, and assert that if no config could be resolved through a
# chain, then the cache should get used (this scenario is ideally for
# nodeadm-run.service using a cached config from nodeadm-config.service).
rm /etc/eks/nodeadm.d/*
nodeadm init --skip config,run --config-source file:///etc/eks/nodeadm.d --config-cache /run/eks/nodeadm/config.json
