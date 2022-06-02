#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
IFS=$'\n\t'

TEMPLATE_DIR=${TEMPLATE_DIR:-/tmp/worker}

################################################################################
### Validate Required Arguments ################################################
################################################################################
validate_env_set() {
    (
        set +o nounset

        if [ -z "${!1}" ]; then
            echo "Packer variable '$1' was not set. Aborting"
            exit 1
        fi
    )
}

validate_env_set BINARY_BUCKET_NAME
validate_env_set BINARY_BUCKET_REGION
validate_env_set DOCKER_VERSION
validate_env_set CONTAINERD_VERSION
validate_env_set RUNC_VERSION
validate_env_set CNI_PLUGIN_VERSION
validate_env_set KUBERNETES_VERSION
validate_env_set KUBERNETES_BUILD_DATE
validate_env_set PULL_CNI_FROM_GITHUB

################################################################################
### Machine Architecture #######################################################
################################################################################

MACHINE=$(uname -m)
if [ "$MACHINE" == "x86_64" ]; then
    ARCH="amd64"
elif [ "$MACHINE" == "aarch64" ]; then
    ARCH="arm64"
else
    echo "Unknown machine architecture '$MACHINE'" >&2
    exit 1
fi

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
    ec2-instance-connect \
    ipvsadm \
    jq \
    nfs-utils \
    socat \
    unzip \
    wget \
    yum-plugin-versionlock \
    yum-utils

# Remove any old kernel versions. `--count=1` here means "only leave 1 kernel version installed"
sudo package-cleanup --oldkernels --count=1 -y

# Remove the ec2-net-utils package, if it's installed. This package interferes with the route setup on the instance.
if yum list installed | grep ec2-net-utils; then sudo yum remove ec2-net-utils -y -q; fi

################################################################################
### Time #######################################################################
################################################################################

# Make sure Amazon Time Sync Service starts on boot.
sudo chkconfig chronyd on

# Make sure that chronyd syncs RTC clock to the kernel.
cat <<EOF | sudo tee -a /etc/chrony.conf
# This directive enables kernel synchronisation (every 11 minutes) of the
# real-time clock. Note that it can’t be used along with the 'rtcfile' directive.
rtcsync
EOF

# If current clocksource is xen, switch to tsc
if grep --quiet xen /sys/devices/system/clocksource/clocksource0/current_clocksource &&
  grep --quiet tsc /sys/devices/system/clocksource/clocksource0/available_clocksource; then
    echo "tsc" | sudo tee /sys/devices/system/clocksource/clocksource0/current_clocksource
else
    echo "tsc as a clock source is not applicable, skipping."
fi

################################################################################
### SSH ########################################################################
################################################################################

# Disable weak ciphers
echo -e "\nCiphers aes128-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd.service

################################################################################
### iptables ###################################################################
################################################################################
sudo mkdir -p /etc/eks
sudo mv $TEMPLATE_DIR/iptables-restore.service /etc/eks/iptables-restore.service

################################################################################
### Docker #####################################################################
################################################################################

sudo yum install -y device-mapper-persistent-data lvm2

INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
if [[ "$INSTALL_DOCKER" == "true" ]]; then
    sudo amazon-linux-extras enable docker
    sudo groupadd -og 1950 docker
    sudo useradd --gid $(getent group docker | cut -d: -f3) docker

    # install runc and lock version
    sudo yum install -y runc-${RUNC_VERSION}
    sudo yum versionlock runc-*

    # install containerd and lock version
    sudo yum install -y containerd-${CONTAINERD_VERSION}
    sudo yum versionlock containerd-*

    # install docker and lock version
    sudo yum install -y docker-${DOCKER_VERSION}*
    sudo yum versionlock docker-*
    sudo usermod -aG docker $USER

    # Remove all options from sysconfig docker.
    sudo sed -i '/OPTIONS/d' /etc/sysconfig/docker

    sudo mkdir -p /etc/docker
    sudo mv $TEMPLATE_DIR/docker-daemon.json /etc/docker/daemon.json
    sudo chown root:root /etc/docker/daemon.json

    # Enable docker daemon to start on boot.
    sudo systemctl daemon-reload
fi

###############################################################################
### Containerd setup ##########################################################
###############################################################################

sudo mkdir -p /etc/eks/containerd
if [ -f "/etc/eks/containerd/containerd-config.toml" ]; then
    ## this means we are building a gpu ami and have already placed a containerd configuration file in /etc/eks
    echo "containerd config is already present"
else 
    sudo mv $TEMPLATE_DIR/containerd-config.toml /etc/eks/containerd/containerd-config.toml
fi

if [[ ! $KUBERNETES_VERSION =~ "1.19"* && ! $KUBERNETES_VERSION =~ "1.20"* && ! $KUBERNETES_VERSION =~ "1.21"* ]]; then
    # enable CredentialProviders features in kubelet-containerd service file
    IMAGE_CREDENTIAL_PROVIDER_FLAGS='\\\n    --image-credential-provider-config /etc/eks/ecr-credential-provider/ecr-credential-provider-config \\\n   --image-credential-provider-bin-dir /etc/eks/ecr-credential-provider'
    sudo sed -i s,"aws","aws $IMAGE_CREDENTIAL_PROVIDER_FLAGS", $TEMPLATE_DIR/kubelet-containerd.service
fi

sudo mv $TEMPLATE_DIR/kubelet-containerd.service /etc/eks/containerd/kubelet-containerd.service
sudo mv $TEMPLATE_DIR/sandbox-image.service /etc/eks/containerd/sandbox-image.service
sudo mv $TEMPLATE_DIR/pull-sandbox-image.sh /etc/eks/containerd/pull-sandbox-image.sh
sudo chmod +x /etc/eks/containerd/pull-sandbox-image.sh

cat <<EOF | sudo tee -a /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF


################################################################################
### Logrotate ##################################################################
################################################################################

# kubelet uses journald which has built-in rotation and capped size.
# See man 5 journald.conf
sudo mv $TEMPLATE_DIR/logrotate-kube-proxy /etc/logrotate.d/kube-proxy
sudo mv $TEMPLATE_DIR/logrotate.conf /etc/logrotate.conf
sudo chown root:root /etc/logrotate.d/kube-proxy
sudo chown root:root /etc/logrotate.conf
sudo mkdir -p /var/log/journal

################################################################################
### Kubernetes #################################################################
################################################################################

sudo mkdir -p /etc/kubernetes/manifests
sudo mkdir -p /var/lib/kubernetes
sudo mkdir -p /var/lib/kubelet
sudo mkdir -p /opt/cni/bin

echo "Downloading binaries from: s3://$BINARY_BUCKET_NAME"
S3_DOMAIN="amazonaws.com"
if [ "$BINARY_BUCKET_REGION" = "cn-north-1" ] || [ "$BINARY_BUCKET_REGION" = "cn-northwest-1" ]; then
    S3_DOMAIN="amazonaws.com.cn"
elif [ "$BINARY_BUCKET_REGION" = "us-iso-east-1" ]; then
    S3_DOMAIN="c2s.ic.gov"
elif [ "$BINARY_BUCKET_REGION" = "us-isob-east-1" ]; then
    S3_DOMAIN="sc2s.sgov.gov"
fi
S3_URL_BASE="https://$BINARY_BUCKET_NAME.s3.$BINARY_BUCKET_REGION.$S3_DOMAIN/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/linux/$ARCH"
S3_PATH="s3://$BINARY_BUCKET_NAME/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/linux/$ARCH"

BINARIES=(
    kubelet
    aws-iam-authenticator
)
for binary in ${BINARIES[*]} ; do
    if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
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

# Since CNI 0.7.0, all releases are done in the plugins repo.
CNI_PLUGIN_FILENAME="cni-plugins-linux-${ARCH}-${CNI_PLUGIN_VERSION}"

if [ "$PULL_CNI_FROM_GITHUB" = "true" ]; then
    echo "Downloading CNI plugins from Github"
    wget "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/${CNI_PLUGIN_FILENAME}.tgz"
    wget "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/${CNI_PLUGIN_FILENAME}.tgz.sha512"
    sudo sha512sum -c "${CNI_PLUGIN_FILENAME}.tgz.sha512"
    rm "${CNI_PLUGIN_FILENAME}.tgz.sha512"
else
    if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
        echo "AWS cli present - using it to copy binaries from s3."
        aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/${CNI_PLUGIN_FILENAME}.tgz .
        aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/${CNI_PLUGIN_FILENAME}.tgz.sha256 .
    else
        echo "AWS cli missing - using wget to fetch cni binaries from s3. Note: This won't work for private bucket."
        sudo wget "$S3_URL_BASE/${CNI_PLUGIN_FILENAME}.tgz"
        sudo wget "$S3_URL_BASE/${CNI_PLUGIN_FILENAME}.tgz.sha256"
    fi
    sudo sha256sum -c "${CNI_PLUGIN_FILENAME}.tgz.sha256"
fi
sudo tar -xvf "${CNI_PLUGIN_FILENAME}.tgz" -C /opt/cni/bin
rm "${CNI_PLUGIN_FILENAME}.tgz"

sudo rm ./*.sha256

sudo mkdir -p /etc/kubernetes/kubelet
sudo mkdir -p /etc/systemd/system/kubelet.service.d
sudo mv $TEMPLATE_DIR/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
sudo chown root:root /var/lib/kubelet/kubeconfig

# Inject CSIServiceAccountToken feature gate to kubelet config if kubernetes version starts with 1.20.
# This is only injected for 1.20 since CSIServiceAccountToken will be moved to beta starting 1.21.
if [[ $KUBERNETES_VERSION == "1.20"* ]]; then
    KUBELET_CONFIG_WITH_CSI_SERVICE_ACCOUNT_TOKEN_ENABLED=$(cat $TEMPLATE_DIR/kubelet-config.json | jq '.featureGates += {CSIServiceAccountToken: true}')
    echo $KUBELET_CONFIG_WITH_CSI_SERVICE_ACCOUNT_TOKEN_ENABLED > $TEMPLATE_DIR/kubelet-config.json
fi

if [[ ! $KUBERNETES_VERSION =~ "1.19"* && ! $KUBERNETES_VERSION =~ "1.20"* && ! $KUBERNETES_VERSION =~ "1.21"* ]]; then
    # enable CredentialProviders feature flags in kubelet service file
    IMAGE_CREDENTIAL_PROVIDER_FLAGS='\\\n    --image-credential-provider-config /etc/eks/ecr-credential-provider/ecr-credential-provider-config \\\n    --image-credential-provider-bin-dir /etc/eks/ecr-credential-provider'
    sudo sed -i s,"aws","aws $IMAGE_CREDENTIAL_PROVIDER_FLAGS", $TEMPLATE_DIR/kubelet.service
    # enable KubeletCredentialProviders features in kubelet configuration
    KUBELET_CREDENTIAL_PROVIDERS_FEATURES=$(cat $TEMPLATE_DIR/kubelet-config.json | jq '.featureGates += {KubeletCredentialProviders: true}')
    printf "%s" "$KUBELET_CREDENTIAL_PROVIDERS_FEATURES" > "$TEMPLATE_DIR/kubelet-config.json"
fi

sudo mv $TEMPLATE_DIR/kubelet.service /etc/systemd/system/kubelet.service
sudo chown root:root /etc/systemd/system/kubelet.service
sudo mv $TEMPLATE_DIR/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
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
sudo mv $TEMPLATE_DIR/max-pods-calculator.sh /etc/eks/max-pods-calculator.sh
sudo chmod +x /etc/eks/max-pods-calculator.sh

SONOBUOY_E2E_REGISTRY="${SONOBUOY_E2E_REGISTRY:-}"
if [[ -n "$SONOBUOY_E2E_REGISTRY" ]]; then
    sudo mv $TEMPLATE_DIR/sonobuoy-e2e-registry-config /etc/eks/sonobuoy-e2e-registry-config
    sudo sed -i s,SONOBUOY_E2E_REGISTRY,$SONOBUOY_E2E_REGISTRY,g /etc/eks/sonobuoy-e2e-registry-config
fi

################################################################################
### ECR CREDENTIAL PROVIDER ####################################################
################################################################################
if [[ ! $KUBERNETES_VERSION =~ "1.19"* && ! $KUBERNETES_VERSION =~ "1.20"* && ! $KUBERNETES_VERSION =~ "1.21"* ]]; then
    ECR_BINARY="ecr-credential-provider"
    if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
        echo "AWS cli present - using it to copy ecr-credential-provider binaries from s3."
        aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/$ECR_BINARY .
    else
        echo "AWS cli missing - using wget to fetch ecr-credential-provider binaries from s3. Note: This won't work for private bucket."
        sudo wget "$S3_URL_BASE/$ECR_BINARY"
    fi
    sudo chmod +x $ECR_BINARY
    sudo mkdir -p /etc/eks/ecr-credential-provider
    sudo mv $ECR_BINARY /etc/eks/ecr-credential-provider

    # copying credential provider config file to eks folder
    sudo mv $TEMPLATE_DIR/ecr-credential-provider-config /etc/eks/ecr-credential-provider/ecr-credential-provider-config
fi

################################################################################
### SSM Agent ##################################################################
################################################################################

sudo yum install -y amazon-ssm-agent

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
sudo chown -R root:root /etc/eks

################################################################################
### Stuff required by "protectKernelDefaults=true" #############################
################################################################################

cat <<EOF | sudo tee -a /etc/sysctl.d/99-amazon.conf
vm.overcommit_memory=1
kernel.panic=10
kernel.panic_on_oops=1
EOF

################################################################################
### Setting up sysctl properties ###############################################
################################################################################

echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
echo fs.inotify.max_user_instances=8192 | sudo tee -a /etc/sysctl.conf
echo vm.max_map_count=524288 | sudo tee -a /etc/sysctl.conf


################################################################################
### Cleanup ####################################################################
################################################################################

CLEANUP_IMAGE="${CLEANUP_IMAGE:-true}"
if [[ "$CLEANUP_IMAGE" == "true" ]]; then
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
fi

sudo touch /etc/machine-id
