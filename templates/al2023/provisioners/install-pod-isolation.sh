#!/usr/bin/env bash

# Installs the pod isolation runtime, which runs a pod inside its own Firecracker
# microVM as a Nitro Enclave sidecar instead of beside its neighbours under runc.
# A pod opts in through the isolated-sandbox or confidential-sandbox RuntimeClass.
#
# Nodes must be launched with EnclaveOptions.Enabled=true.

set -o pipefail
set -o nounset
set -o errexit

if [ "${ENABLE_POD_ISOLATION}" != "true" ]; then
  echo "Pod isolation is not enabled, skipping"
  exit 0
fi

# The runtime and guest image are published for these Kubernetes minor versions
# only.
case "$(echo "${KUBERNETES_VERSION}" | cut -d. -f1,2)" in
  1.36 | 1.37) ;;
  *)
    echo "ERROR: pod isolation supports Kubernetes 1.36 and 1.37, not ${KUBERNETES_VERSION}" >&2
    exit 1
    ;;
esac

################################################################################
### Configuration ##############################################################
################################################################################

# The runtime and guest image come from the same bundle as the other node
# components (see install-worker.sh), as <artifact>/linux/<arch>/ under it.
readonly BUNDLE_S3_URI="s3://${BINARY_BUCKET_NAME}/${KUBERNETES_VERSION}/${KUBERNETES_BUILD_DATE}"

# Guest boot artifacts.
readonly IMAGES_DIR="/var/lib/nitro-sandbox-images"

# Jailer chroot base, per-VM drive images, sockets and the shim log.
readonly STATE_DIR="/var/lib/nitro-sandbox"

# cri-proxy and the sandbox device plugin are subcommands of this binary, so
# neither installs a binary of its own.
readonly SHIM_BINARY="containerd-shim-nitro-sandbox-v2"

readonly OVERLAY="${WORKING_DIR}/pod-isolation"

# `uname -m` names, as Firecracker and the jailer are keyed.
case "$(uname -m)" in
  x86_64 | aarch64) ARCH="$(uname -m)" ;;
  *)
    echo "ERROR: unsupported architecture $(uname -m)" >&2
    exit 1
    ;;
esac
readonly ARCH

# The artifact bucket keys by Go-style `amd64` / `arm64`, not `uname -m` names.
case "${ARCH}" in
  x86_64) GUEST_ARCH="amd64" ;;
  aarch64) GUEST_ARCH="arm64" ;;
esac
readonly GUEST_ARCH

echo "Installing the pod isolation runtime for ${ARCH} from ${BUNDLE_S3_URI}"

sudo install -d -m 0755 "${IMAGES_DIR}" "${STATE_DIR}"

# shellcheck disable=SC1090
source "${WORKING_DIR}/helpers/aws-clients.sh"

# Download one object from a given S3 base URI. Integrity is the caller's
# problem; see `fetch_from` for the `.sha256`-verified variant. aws_s3 retries
# unsigned, so a public bucket is readable without an instance profile.
download_from() {
  local base="$1" key="$2" dest="$3" mode="$4"
  local tmp="${WORKING_DIR}/download.$$"

  echo "Fetching ${base}/${key}"
  if ! aws_s3 cp --quiet --region "${BINARY_BUCKET_REGION}" "${base}/${key}" "${tmp}"; then
    echo "ERROR: could not fetch ${base}/${key}." >&2
    return 1
  fi
  sudo mv "${tmp}" "${dest}"
  sudo chown root:root "${dest}"
  sudo chmod "${mode}" "${dest}"
}

# Download from a given S3 base URI and verify against the `.sha256` sidecar
# beside the object. Compared by hash value, not `sha256sum -c`, since the name
# the sidecar records is relative to where the checksums were generated.
fetch_from() {
  local base="$1" key="$2" dest="$3" mode="$4"
  local expected actual

  download_from "${base}" "${key}" "${dest}" "${mode}"

  expected=$(aws_s3 cp --quiet --region "${BINARY_BUCKET_REGION}" "${base}/${key}.sha256" - | awk '{print $1}')
  actual=$(sudo sha256sum "${dest}" | awk '{print $1}')
  if [ "${expected}" != "${actual}" ]; then
    echo "ERROR: checksum mismatch for ${key}" >&2
    echo "       expected ${expected}" >&2
    echo "       actual   ${actual}" >&2
    return 1
  fi
  echo "  -> ${dest}"
}

################################################################################
### Packages ###################################################################
################################################################################
# The shim execs `mkfs.erofs` to build the erofs image the guest mounts for a
# container's root filesystem. Without it, container start fails with ENOENT,
# which reads like a missing file rather than a missing package.
sudo dnf install -y erofs-utils

################################################################################
### Host kernel ################################################################
################################################################################
# The sandbox extensions to the nitro_enclaves driver are in the stock Amazon
# Linux kernel from ${POD_ISOLATION_MIN_KERNEL} onwards, so no kernel is
# installed from elsewhere. Earlier kernels carry the driver but not the
# extensions: the sidecar ioctls are missing, the node advertises no sandbox
# capacity, and nothing can be scheduled. Standalone enclaves work there;
# sidecars do not.
#
# The base image usually already satisfies this, in which case dnf reports
# nothing to do. Asserting it here rather than assuming it means an older base
# image fails the build instead of producing an AMI that registers fine and then
# refuses every sandboxed pod.
sudo dnf install -y "kernel6.18 >= ${POD_ISOLATION_MIN_KERNEL}"

################################################################################
### Boot arguments #############################################################
################################################################################
# The Nitro Sandbox memory pool must be reserved at boot with the
# nitro_enclaves.mempool kernel parameter; a sandbox fails to start if the pool is
# not reserved. The shim checks it before starting every sandbox, so a node
# without it registers fine and then refuses every sandboxed pod. Each sandbox
# takes its full memory from the pool when it starts and returns it only when it
# terminates.
set-kernel-arg "nitro_enclaves.mempool=${POD_ISOLATION_ENCLAVE_MEMPOOL}"

################################################################################
### Runtime ####################################################################
################################################################################

# The VMM each isolated pod runs inside, and the jailer that confines it, from
# the upstream Firecracker release. The tarball is checked against the
# .sha256.txt published beside it before anything is extracted.
install_firecracker() {
  local version="${POD_ISOLATION_FIRECRACKER_VERSION}"
  local name="firecracker-${version}-${ARCH}.tgz"
  local url="https://github.com/firecracker-microvm/firecracker/releases/download/${version}/${name}"
  local dir="${WORKING_DIR}/firecracker"
  local expected actual

  mkdir -p "${dir}"
  echo "Fetching ${url}"
  curl --fail --silent --show-error --location --retry 3 --output "${dir}/${name}" "${url}"
  expected=$(curl --fail --silent --show-error --location --retry 3 "${url}.sha256.txt" | awk '{print $1}')
  actual=$(sha256sum "${dir}/${name}" | awk '{print $1}')
  if [ -z "${expected}" ] || [ "${expected}" != "${actual}" ]; then
    echo "ERROR: checksum mismatch for ${name}" >&2
    echo "       expected ${expected}" >&2
    echo "       actual   ${actual}" >&2
    return 1
  fi

  # The tarball holds release-<version>-<arch>/{firecracker,jailer}-<version>-<arch>.
  tar -xzf "${dir}/${name}" -C "${dir}"
  for binary in firecracker jailer; do
    sudo install -m 0755 "${dir}/release-${version}-${ARCH}/${binary}-${version}-${ARCH}" "/usr/bin/${binary}"
    echo "  -> /usr/bin/${binary}"
  done

  rm -rf "${dir}"
}

install_firecracker

# The runtime containerd hands a sandbox to, in the slot runc occupies for an
# ordinary pod. The release archive is checked against its `.sha256` sidecar like
# the other bundle artifacts.
#
# The archive also carries the guest agent, the ocicrypt keyprovider, both
# genpolicy binaries and the policy evaluator. Only the shim is installed: the
# agent lives in the guest image, and the rest are workstation tools.
install_runtime_archive() {
  local dir="${WORKING_DIR}/runtime"

  mkdir -p "${dir}"
  fetch_from "${BUNDLE_S3_URI}/nitro-sandboxes-runtime/linux/${GUEST_ARCH}" \
    "nitro-sandboxes-runtime.tar.gz" "${dir}/nitro-sandboxes-runtime.tar.gz" 0644

  tar -xzf "${dir}/nitro-sandboxes-runtime.tar.gz" -C "${dir}" "${SHIM_BINARY}"
  sudo install -m 0755 "${dir}/${SHIM_BINARY}" "/usr/bin/${SHIM_BINARY}"
  echo "  -> /usr/bin/${SHIM_BINARY}"

  rm -rf "${dir}"
}

install_runtime_archive

# The guest, as an EIF plus its disk. Firecracker loads the EIF directly with the kernel command line baked in,
# which is why nitro-sandbox.toml sets no boot_args. The pair must come from one
# build: the disk is a dm-verity image whose root hash is in the EIF's measured
# command line, so a mismatch fails at guest boot.
fetch_from "${BUNDLE_S3_URI}/nitro-sandbox-guest/linux/${GUEST_ARCH}" "nitro-sandbox-guest.eif" "${IMAGES_DIR}/latest.eif" 0644
fetch_from "${BUNDLE_S3_URI}/nitro-sandbox-guest/linux/${GUEST_ARCH}" "nitro-sandbox-guest-disk.img" "${IMAGES_DIR}/latest-disk.img" 0644

# The shim attaches the guest disk as "rootfs.ext4" from the directory holding
# the kernel it was given.
sudo ln -sf latest-disk.img "${IMAGES_DIR}/rootfs.ext4"

# The guest agent needs no host install; it is part of the guest image.

sudo install -D -m 0644 "${OVERLAY}/nitro-sandbox.toml" /etc/containerd/nitro-sandbox.toml

# The shim creates a TAP device per microVM; without tun, sandbox creation fails.
sudo install -D -m 0644 "${OVERLAY}/nitro-sandbox-modules.conf" /etc/modules-load.d/nitro-sandbox.conf

################################################################################
### CRI proxy ##################################################################
################################################################################
# Routes isolated pods to the right runtime in front of kubelet and advertises
# how many sandboxes the node can hold.
sudo install -D -m 0644 "${OVERLAY}/cri-proxy.service" /etc/systemd/system/cri-proxy.service
sudo install -D -m 0644 "${OVERLAY}/restart-with-cri-proxy.conf" \
  /etc/systemd/system/kubelet.service.d/restart-with-cri-proxy.conf

# Enabled, not started: there is no containerd to talk to on the builder.
sudo systemctl daemon-reload
sudo systemctl enable cri-proxy.service

################################################################################
### containerd and kubelet configuration #######################################
################################################################################
# nodeadm regenerates /etc/containerd/config.toml and the kubelet config from
# templates on every boot, so edits made here would be discarded before
# containerd first starts. The runtime handlers, discard_unpacked_layers and
# kubelet's containerRuntimeEndpoint ship as a NodeConfig drop-in instead, which
# nodeadm reads as a config source and merges over user data.
sudo install -D -m 0644 "${OVERLAY}/10-pod-isolation.yaml" /etc/eks/nodeadm.d/10-pod-isolation.yaml

echo "Pod isolation runtime installed"
