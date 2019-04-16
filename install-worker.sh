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
    awscli \
    chrony \
    conntrack \
    curl \
    jq \
    nfs-utils \
    amazon-ssm-agent \
    aide\
    less \
    socat \
    unzip \
    wget

# Make sure Amazon Time Sync Service starts on boot.
sudo chkconfig chronyd on

# Make sure that chronyd syncs RTC clock to the kernel.
cat <<EOF | sudo tee -a /etc/chrony.conf
# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can’t be used along with the 'rtcfile' directive.
rtcsync
EOF

################################################################################
### ClamAv #####################################################################
################################################################################

# Install epel repo
sudo amazon-linux-extras install -y epel

# Install ClamAv
sudo yum -y install clamav-server clamav-data clamav-update clamav-filesystem clamav clamav-scanner-systemd clamav-devel clamav-lib clamav-server-systemd
sudo yum -y install man

sudo sed -i -e "s/^Example/#Example/" /etc/clamd.d/scan.conf

sudo sh -c 'echo "LocalSocket /var/run/clamd.scan/clamd.sock" >> /etc/clamd.d/scan.conf'
sudo su -c 'echo "FixStaleSocket yes" >> /etc/clamd.d/scan.conf'
sudo su -c 'echo "LogFile /var/log/clamd.log" >> /etc/clamd.d/scan.conf'


sudo freshclam

#sudo systemctl enable clamd@scan
#sudo systemctl start clamd@scan




################################################################################
### iptables ###################################################################
################################################################################

# Enable forwarding via iptables
sudo bash -c "/sbin/iptables-save > /etc/sysconfig/iptables"

sudo mv $TEMPLATE_DIR/iptables-restore.service /etc/systemd/system/iptables-restore.service

sudo systemctl daemon-reload
sudo systemctl enable iptables-restore

################################################################################
### Docker #####################################################################
################################################################################

sudo yum install -y yum-utils device-mapper-persistent-data lvm2

INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
if [[ "$INSTALL_DOCKER" == "true" ]]; then
    sudo amazon-linux-extras enable docker
    DOCKER_VERSION=${DOCKER_VERSION:-"18.06"}
    sudo yum install -y docker-${DOCKER_VERSION}*
    sudo usermod -aG docker $USER

    # Remove all options from sysconfig docker.
    sudo sed -i '/OPTIONS/d' /etc/sysconfig/docker

    sudo mkdir -p /etc/docker
    sudo mv $TEMPLATE_DIR/docker-daemon.json /etc/docker/daemon.json
    sudo chown root:root /etc/docker/daemon.json

    # Enable docker daemon to start on boot.
    sudo systemctl daemon-reload
    sudo systemctl enable docker
fi

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
S3_PATH="s3://$BINARY_BUCKET_NAME/$BINARY_BUCKET_PATH"
BINARIES=(
    kubelet
    kubectl
    aws-iam-authenticator
)
for binary in ${BINARIES[*]} ; do
    if [[ ! -z "$AWS_ACCESS_KEY_ID" ]]; then
        echo "AWS cli present - using it to copy binaries from s3."
        aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/$binary .
        aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/$binary.sha256 .
    else
        echo "AWS cli missing - using wget to fetch binaries from s3. Note: This won't work for private bucket."
        sudo wget $S3_URL_BASE/$binary
        sudo wget $S3_URL_BASE/$binary.sha256
    fi
    sudo sha256sum -c $binary.sha256
    sudo chmod +x $binary
    sudo mv $binary /usr/bin/
done
sudo rm *.sha256

KUBELET_CONFIG=""
if [ "$KUBERNETES_VERSION" = "1.10" ] || [ "$KUBERNETES_VERSION" = "1.11" ]; then
    KUBELET_CONFIG=kubelet-config.json
else
    # For newer versions use this config to fix https://github.com/kubernetes/kubernetes/issues/74412.
    KUBELET_CONFIG=kubelet-config-with-secret-polling.json
fi

sudo mkdir -p /etc/kubernetes/kubelet
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo mv $TEMPLATE_DIR/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
sudo chown root:root /var/lib/kubelet/kubeconfig
sudo mv $TEMPLATE_DIR/kubelet.service /etc/systemd/system/kubelet.service
sudo chown root:root /etc/systemd/system/kubelet.service
sudo mv $TEMPLATE_DIR/$KUBELET_CONFIG /etc/kubernetes/kubelet/kubelet-config.json
sudo chown root:root /etc/kubernetes/kubelet/kubelet-config.json


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
ARCH="$(uname -m)"
EOF
sudo mv /tmp/release /etc/eks/release
sudo chown root:root /etc/eks/*









################################################################################
### Cleanup ####################################################################
################################################################################

# Clean up yum caches to reduce the image size
sudo yum clean all
sudo rm -rf \
    $TEMPLATE_DIR  \
    /var/cache/yum

# Clean up files to reduce confusion during debug
sudo rm -rf \
    /etc/hostname \
    /etc/machine-id \
    /etc/resolv.conf \
    /etc/ssh/ssh_host* \
    /home/ec2-user/.ssh/authorized_keys \
    /root/.ssh/authorized_keys \
    /var/lib/cloud/data \
    /var/lib/cloud/instance \
    /var/lib/cloud/instances \
    /var/lib/cloud/sem \
    /var/lib/dhclient/* \
    /var/lib/dhcp/dhclient.* \
    /var/lib/yum/history \
    /var/log/cloud-init-output.log \
    /var/log/cloud-init.log \
    /var/log/secure \
    /var/log/wtmp

sudo touch /etc/machine-id

################################################################################
### AIDE #######################################################################
################################################################################

# ignore /var 
sudo sh -c "echo '!/var' >> /etc/aide.conf"
sudo sh -c "echo '!/opt/cni' >> /etc/aide.conf"
sudo sh -c "echo '!/etc/cni' >> /etc/aide.conf"
sudo sh -c "echo '!/etc/kubernetes/pki' >> /etc/aide.conf"
sudo sh -c "echo '!/etc/systemd/system' >> /etc/aide.conf"

sudo touch /var/log/clamav.log
sudo touch /var/log/aide/aide.log

# generate crontab 
sudo crontab /tmp/lessonly/lessonly-crontab

sudo cp /tmp/lessonly/aide-startup.sh /bin/
sudo chmod a+x /bin/aide-startup.sh

sudo cp /tmp/lessonly/aide-startup.service /etc/systemd/system/ 
sudo cp /tmp/lessonly/sysconfig-docker /etc/sysconfig/docker 

sudo systemctl enable aide-startup.service

sudo mv -f /tmp/lessonly/limits.conf /etc/security/limits.conf

# Update network sysctl settings
sudo cp /tmp/lessonly/network-sysctl.conf /etc/sysctl.d/network-sysctl.conf


# build aide library
sudo aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz