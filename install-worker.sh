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
sudo yum update -y

# Install necessary packages
sudo yum install -y \
  aws-cfn-bootstrap \
  conntrack \
  curl \
  nfs-utils \
  ntp \
  ntpdate \
  socat \
  unzip \
  util-linux \
  wget

curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
sudo python get-pip.py
rm get-pip.py
sudo pip install --upgrade awscli

if which swapoff ; then
  sudo swapoff --all --verbose
fi

################################################################################
### Date/Time ##################################################################
################################################################################

sudo timedatectl set-timezone UTC
sudo systemctl stop ntpd
sudo systemctl disable ntpd
sudo systemctl mask ntpd

cat <<EOF | sudo tee /etc/systemd/timesyncd.conf
[Time]
NTP=0.amazon.pool.ntp.org 1.amazon.pool.ntp.org 2.amazon.pool.ntp.org 3.amazon.pool.ntp.org
EOF

sudo mkdir -p /etc/systemd/network
cat <<EOF | sudo tee /etc/systemd/network/50-network.conf
[Network]
DHCP=v4
NTP=0.amazon.pool.ntp.org 1.amazon.pool.ntp.org 2.amazon.pool.ntp.org 3.amazon.pool.ntp.org

[DHCP]
UseMTU=true
UseDomains=true
UseNTP=false
EOF

sudo mv $TEMPLATE_DIR/ntpdate-sync.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ntpdate-sync.timer

################################################################################
### System Modules #############################################################
################################################################################

sudo mkdir -vp /etc/modules-load.d
cat <<EOF | sudo tee /etc/modules-load.d/extra_modules.conf
nf_conntrack_ipv4
EOF

sudo systemctl daemon-reload
sudo systemctl enable systemd-modules-load
sudo systemctl restart systemd-modules-load

sudo mkdir -p /etc/sysctl.d
cat <<EOF | sudo tee /etc/sysctl.d/99-lumos.conf
vm.swapiness = 0

net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.core.rmem_default = 65536
net.core.wmem_default = 65536
net.ipv4.tcp_rmem = 8192 873800 8388608
net.ipv4.tcp_wmem = 4096 655360 8388608
net.ipv4.tcp_mem = 8388608 8388608 8388608
net.ipv4.tcp_max_tw_buckets = 6000000
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.tcp_max_orphans = 262144
net.core.somaxconn = 16384
net.core.netdev_max_backlog = 16384
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_fin_timeout = 7
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.ip_local_port_range = 10000 65535
EOF

sudo systemctl daemon-reload
sudo systemctl enable systemd-sysctl
sudo systemctl restart systemd-sysctl

sudo mkdir -p /etc/security/limits.d
cat <<EOF | sudo tee /etc/security/limits.d/99-nofile.conf
*          soft    nofile     65535
*          hard    nofile     65535
EOF

################################################################################
### iptables ###################################################################
################################################################################

# Enable forwarding via iptables
sudo iptables -P FORWARD ACCEPT
sudo bash -c "/sbin/iptables-save > /etc/sysconfig/iptables"

sudo mv $TEMPLATE_DIR/iptables-restore.service /etc/systemd/system/iptables-restore.service

sudo systemctl daemon-reload
sudo systemctl enable iptables-restore

################################################################################
### Docker #####################################################################
################################################################################
# mount secondary drive to var/lib/docker
sudo mkfs -t xfs -n ftype=1 /dev/nvme1n1
sudo mkdir -vp /var/lib/docker
sudo mount /dev/nvme1n1 /var/lib/docker
sudo bash -c "echo -e '/dev/nvme1n1\t/var/lib/docker\txfs\tdefaults,nofail\t0\t2' >> /etc/fstab"
sudo cat /etc/fstab
# install docker
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo amazon-linux-extras enable docker
sudo yum install -y docker-${DOCKER_VERSION}*
sudo usermod -aG docker $USER
sudo mkdir -vp /etc/docker
sudo mv $TEMPLATE_DIR/dockerd.json /etc/docker/daemon.json

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

sudo mv -v $TEMPLATE_DIR/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
sudo mv -v $TEMPLATE_DIR/kubelet.service /etc/systemd/system/kubelet.service
sudo mv -v $TEMPLATE_DIR/kubelet-configuration.yaml /var/lib/kubelet/kubelet-configuration.yaml
sudo mkdir -p /etc/systemd/system/kubelet.service.d

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

# Clean up yum caches to reduce the image size
sudo yum clean all
sudo rm -rf \
  $TEMPLATE_DIR  \
  /var/cache/yum

# Clean up files to reduce confusion during debug
sudo rm -rf \
  /etc/machine-id \
  /etc/ssh/ssh_host* \
  /root/.ssh/authorized_keys \
  /home/ec2-user/.ssh/authorized_keys \
  /var/log/secure \
  /var/log/wtmp \
  /var/lib/cloud/sem \
  /var/lib/cloud/data \
  /var/lib/cloud/instance \
  /var/lib/cloud/instances \
  /var/log/cloud-init.log \
  /var/log/cloud-init-output.log

sudo touch /etc/machine-id
