#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
IFS=$'\n\t'

TEMPLATE_DIR=${TEMPLATE_DIR:-/tmp/worker}

################################################################################
### Packages ###################################################################
################################################################################

# Update the OS to begin with to catch up to the latest packages.
sudo apt-get clean
sudo apt update
sudo apt-get update
sudo apt-get upgrade -y >/dev/null

# Install necessary packages
sudo apt-get install -y --no-install-recommends \
    awscli \
    conntrack \
    curl \
    htop \
    jq \
    nfs-common \
    nmap \
    ntp \
    socat \
    screen \
    sysstat \
    unzip \
    wget \
    >/dev/null

sudo systemctl enable ntp

################################################################################
### iptables ###################################################################
################################################################################

# Enable forwarding via iptables
sudo bash -c "/sbin/iptables-save > /etc/iptables.rules"

sudo mv $TEMPLATE_DIR/iptables-restore.service /etc/systemd/system/iptables-restore.service

sudo systemctl daemon-reload
sudo systemctl enable iptables-restore

################################################################################
### Docker #####################################################################
################################################################################

sudo apt-get install -y --no-install-recommends docker.io=17.12.1-0ubuntu1
sudo usermod -aG docker $USER

sudo mkdir -p /etc/docker
sudo chmod 700 /etc/docker
sudo mv $TEMPLATE_DIR/docker-daemon.json /etc/docker/daemon.json
sudo chown root:root /etc/docker/daemon.json

# Enable docker daemon to start on boot.
sudo systemctl daemon-reload
sudo systemctl enable docker

################################################################################
### Logrotate ##################################################################
################################################################################

# kubelet uses journald which has built-in rotation and capped size.
# See man 5 journald.conf
sudo mv $TEMPLATE_DIR/logrotate-kube-proxy /etc/logrotate.d/kube-proxy
sudo chown root:root /etc/logrotate.d/kube-proxy
sudo mkdir -p /var/log/journal

################################################################################
### Kubernetes #################################################################
################################################################################

sudo mkdir -p /etc/kubernetes/manifests
sudo mkdir -p /var/lib/kubernetes
sudo mkdir -p /var/lib/kubelet
sudo mkdir -p /opt/cni/bin

CNI_VERSION=${CNI_VERSION:-"v0.6.0"}
wget https://github.com/containernetworking/cni/releases/download/${CNI_VERSION}/cni-amd64-${CNI_VERSION}.tgz
wget https://github.com/containernetworking/cni/releases/download/${CNI_VERSION}/cni-amd64-${CNI_VERSION}.tgz.sha512
sudo sha512sum -c cni-amd64-${CNI_VERSION}.tgz.sha512
sudo tar -xvf cni-amd64-${CNI_VERSION}.tgz -C /opt/cni/bin
rm cni-amd64-${CNI_VERSION}.tgz cni-amd64-${CNI_VERSION}.tgz.sha512

CNI_PLUGIN_VERSION=${CNI_PLUGIN_VERSION:-"v0.7.1"}
wget https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-amd64-${CNI_PLUGIN_VERSION}.tgz
wget https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-amd64-${CNI_PLUGIN_VERSION}.tgz.sha512
sudo sha512sum -c cni-plugins-amd64-${CNI_PLUGIN_VERSION}.tgz.sha512
sudo tar -xvf cni-plugins-amd64-${CNI_PLUGIN_VERSION}.tgz -C /opt/cni/bin
rm cni-plugins-amd64-${CNI_PLUGIN_VERSION}.tgz cni-plugins-amd64-${CNI_PLUGIN_VERSION}.tgz.sha512

echo "Downloading binaries from: s3://$BINARY_BUCKET_NAME"
S3_DOMAIN="s3-$BINARY_BUCKET_REGION"
if [ "$BINARY_BUCKET_REGION" = "us-east-1" ]; then
    S3_DOMAIN="s3"
fi
S3_URL_BASE="https://$S3_DOMAIN.amazonaws.com/$BINARY_BUCKET_NAME/$BINARY_BUCKET_PATH"

BINARIES=(
    kubelet
    kubectl
    aws-iam-authenticator
)
for binary in ${BINARIES[*]} ; do
    sudo wget $S3_URL_BASE/$binary
    sudo wget $S3_URL_BASE/$binary.sha256
    sudo sha256sum -c $binary.sha256
    sudo chmod +x $binary
    sudo mv $binary /usr/bin/
done
sudo rm *.sha256

sudo mkdir -p /etc/kubernetes/kubelet
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo mv $TEMPLATE_DIR/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
sudo chown root:root /var/lib/kubelet/kubeconfig
sudo mv $TEMPLATE_DIR/kubelet.service /etc/systemd/system/kubelet.service
sudo chown root:root /etc/systemd/system/kubelet.service
sudo mv $TEMPLATE_DIR/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
sudo chown root:root /etc/kubernetes/kubelet/kubelet-config.json


sudo mv $TEMPLATE_DIR/health-monitor.sh /usr/local/bin/health-monitor.sh
sudo mv $TEMPLATE_DIR/kubelet-monitor.service /etc/systemd/system/kubelet-monitor.service
sudo mv $TEMPLATE_DIR/kube-container-runtime-monitor.service /etc/systemd/system/kube-container-runtime-monitor.service

sudo systemctl daemon-reload
# Disable the kubelet until the proper dropins have been configured
sudo systemctl disable kubelet

################################################################################
### EKS ########################################################################
################################################################################

sudo mkdir -p /etc/eks
sudo mv $TEMPLATE_DIR/eni-max-pods.txt /etc/eks/eni-max-pods.txt
sudo mv $TEMPLATE_DIR/bootstrap.sh /etc/eks/bootstrap.sh
sudo chmod +x /etc/eks/bootstrap.sh

################################################################################
### AMI Metadata ###############################################################
################################################################################

BASE_AMI_ID=$(curl -s  http://169.254.169.254/latest/meta-data/ami-id)
cat <<EOF > /tmp/release
BASE_AMI_ID="$BASE_AMI_ID"
BUILD_TIME="$(date)"
BUILD_KERNEL="$(uname -r)"
AMI_NAME="$AMI_NAME"
ARCH="$(uname -m)"
EOF
sudo mv /tmp/release /etc/eks/release
sudo chown root:root /etc/eks/*

################################################################################
### Cleanup ####################################################################
################################################################################

# Clean up yum caches to reduce the image size
sudo apt-get autoremove -y
sudo rm -rf \
    $TEMPLATE_DIR  \
    /var/lib/apt/lists \
    /var/cache/apt/archives

# Clean up files to reduce confusion during debug
sudo rm -rf \
    /etc/machine-id \
    /etc/ssh/ssh_host* \
    /root/.ssh/authorized_keys \
    /home/ubuntu/.ssh/authorized_keys \
    /var/log/secure \
    /var/log/wtmp \
    /var/lib/cloud/sem \
    /var/lib/cloud/data \
    /var/lib/cloud/instance \
    /var/lib/cloud/instances \
    /var/log/cloud-init.log \
    /var/log/cloud-init-output.log

sudo touch /etc/machine-id
