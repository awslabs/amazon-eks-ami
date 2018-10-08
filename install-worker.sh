#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
IFS=$'\n\t'

TEMPLATE_DIR=${TEMPLATE_DIR:-/tmp/worker}

################################################################################
### Nvidia driver ##############################################################
################################################################################
sudo yum -y erase nvidia cuda
sudo yum install -y gcc kernel-devel-$(uname -r) dkms

# Downloading and installing the NVIDIA GRID Driver (G3)
# https://gist.github.com/wangruohui/df039f0dc434d6486f5d4d098aa52d07#install-dependencies
# option -s is used for silent installation which should used for batch installation. For installation on a single computer, this option should be turned off for more installtion information
# option --dkms is used for register dkms module into the kernel so that update of the kernel will not require a reinstallation of the driver. This option should be turned on by default. 
aws s3 cp --recursive s3://ec2-linux-nvidia-drivers/latest/ .
sudo /bin/sh ./NVIDIA-Linux-x86_64*.run --dkms -s

# Optimizing GPU Settings (P2, P3, and G3 Instances)
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-nvidia-driver.html
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/optimize_gpu.html
sudo nvidia-smi -q | head
sudo nvidia-persistenced
sudo nvidia-smi --auto-boost-default=0
sudo nvidia-smi -ac 2505,1177


################################################################################
### Activate NVIDIA GRID Virtual Applications (G3 Instances Only) ##############
################################################################################
sudo chmod 666 /etc/nvidia/gridd.conf.template
sudo sed -i "s/^FeatureType.*/FeatureType=0/g" /etc/nvidia/gridd.conf.template
sudo echo "IgnoreSP=TRUE" >> /etc/nvidia/gridd.conf.template
sudo rm -rf /etc/nvidia/gridd.conf
sudo echo "Removed NVIDIA GRID original config, override it from template."
sudo cp -fpa /etc/nvidia/gridd.conf.template /etc/nvidia/gridd.conf
sudo echo "Activated NVIDIA GRID Virtual Applications."


################################################################################
### Docker #####################################################################
################################################################################

sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo amazon-linux-extras enable docker
sudo yum install -y docker-17.06*
sudo usermod -aG docker $USER


# Add the package repositories
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | \
  sudo tee /etc/yum.repos.d/nvidia-docker.repo

# Install nvidia-docker2 and reload the Docker daemon configuration
sudo yum install -y nvidia-docker2

# Debug docker service options
sudo mkdir /etc/systemd/system/docker.service.d
sudo ls -lah /etc/systemd/system/docker.service.d/

# Create /etc/systemd/system/docker.service.d/nvidia-docker-dropin.conf
sudo touch /etc/systemd/system/docker.service.d/nvidia-docker-dropin.conf
sudo chmod 666 /etc/systemd/system/docker.service.d/nvidia-docker-dropin.conf
sudo echo "[Service]" >> /etc/systemd/system/docker.service.d/nvidia-docker-dropin.conf
sudo echo "ExecStart=" >> /etc/systemd/system/docker.service.d/nvidia-docker-dropin.conf
sudo echo "ExecStart=/usr/bin/dockerd --default-runtime=nvidia" >> /etc/systemd/system/docker.service.d/nvidia-docker-dropin.conf

# Enable docker daemon to start on boot.
sudo systemctl daemon-reload
sudo systemctl enable docker

################################################################################
### Logrotate ##################################################################
################################################################################

# kubelet uses journald which has built-in rotation and capped size.
# See man 5 journald.conf
sudo mv $TEMPLATE_DIR/logrotate-kube-proxy /etc/logrotate.d/kube-proxy
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

sudo mv $TEMPLATE_DIR/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
sudo mv $TEMPLATE_DIR/kubelet.service /etc/systemd/system/kubelet.service
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