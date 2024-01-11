#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
set -x

# use containerd to build nodeadm containerized via kaniko + nerdctl
sudo systemctl enable --now containerd
sudo nerdctl run \
  --rm \
  -v $NODEADM_DIR:/workspace \
  gcr.io/kaniko-project/executor:latest \
  --dockerfile /workspace/Dockerfile \
  --context dir:///workspace/ \
  --no-push
sudo systemctl disable containerd

# move the nodeadm binary into bin folder
sudo chmod a+x $NODEADM_DIR/_dist/bin/linux/amd64/nodeadm
sudo mv $NODEADM_DIR/_dist/bin/linux/amd64/nodeadm /usr/bin/

if [ -d $NODEADM_DIR/rootfs/usr/bin/ ]; then
  sudo chmod -R a+x $NODEADM_DIR/rootfs/usr/bin/
fi

# overlay the expected services and binaries from the bootstrap archive onto the filesystem
sudo cp -rv $NODEADM_DIR/rootfs/* /

# enable nodeadm bootstrap systemd unit
sudo systemctl enable nodeadm-configure nodeadm-run
