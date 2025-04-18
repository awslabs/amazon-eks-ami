#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit
IFS=$'\n\t'
export AWS_DEFAULT_OUTPUT="json"

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
validate_env_set CONTAINERD_VERSION
validate_env_set KUBERNETES_BUILD_DATE
validate_env_set KUBERNETES_VERSION
validate_env_set RUNC_VERSION
validate_env_set WORKING_DIR

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
sudo dnf update -y

# Install necessary packages
sudo dnf install -y \
  aws-cfn-bootstrap \
  chrony \
  conntrack \
  ec2-instance-connect \
  ethtool \
  ipvsadm \
  jq \
  nfs-utils \
  socat \
  unzip \
  wget \
  mdadm \
  pigz

################################################################################
### Networking #################################################################
################################################################################

# needed by kubelet
sudo dnf install -y iptables-nft

# Mask udev triggers installed by amazon-ec2-net-utils package
sudo touch /etc/udev/rules.d/99-vpc-policy-routes.rules

# Make networkd ignore foreign settings, else it may unexpectedly delete IP rules and routes added by CNI
sudo mkdir -p /usr/lib/systemd/networkd.conf.d/
cat << EOF | sudo tee /usr/lib/systemd/networkd.conf.d/80-release.conf
# Do not clobber any routes or rules added by CNI.
[Network]
ManageForeignRoutes=no
ManageForeignRoutingPolicyRules=no
EOF

# Temporary fix for https://github.com/aws/amazon-vpc-cni-k8s/pull/2118
sudo mkdir -p /etc/systemd/network/99-default.link.d/
cat << EOF | sudo tee /etc/systemd/network/99-default.link.d/99-no-policy.conf
# Ensure MACAddressPolicy=none, reinstalling systemd-udev writes /usr/lib/systemd/network/99-default.link
# with value set to persistent
# https://github.com/aws/amazon-vpc-cni-k8s/issues/2103#issuecomment-1321698870
[Link]
MACAddressPolicy=none
EOF

################################################################################
### SSH ########################################################################
################################################################################

# Disable weak ciphers
echo -e "\nCiphers aes128-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd.service

################################################################################
### awscli #####################################################################
################################################################################

### isolated regions can't communicate to awscli.amazonaws.com so installing awscli through dnf
ISOLATED_REGIONS="${ISOLATED_REGIONS:-us-iso-east-1 us-iso-west-1 us-isob-east-1 eu-isoe-west-1 us-isof-south-1}"
if ! [[ ${ISOLATED_REGIONS} =~ $BINARY_BUCKET_REGION ]]; then
  # https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
  echo "Installing awscli v2 bundle"
  AWSCLI_DIR="${WORKING_DIR}/awscli-install"
  mkdir "${AWSCLI_DIR}"
  curl \
    --silent \
    --show-error \
    --retry 10 \
    --retry-delay 1 \
    -L "https://awscli.amazonaws.com/awscli-exe-linux-${MACHINE}.zip" -o "${AWSCLI_DIR}/awscliv2.zip"
  unzip -q "${AWSCLI_DIR}/awscliv2.zip" -d ${AWSCLI_DIR}
  sudo "${AWSCLI_DIR}/aws/install" --bin-dir /bin/ --update
else
  echo "Installing awscli package"
  sudo dnf install -y awscli
fi

###############################################################################
### Containerd setup ##########################################################
###############################################################################

sudo dnf install -y runc-${RUNC_VERSION}
sudo dnf install -y containerd-${CONTAINERD_VERSION}

sudo systemctl enable ebs-initialize-bin@containerd

###############################################################################
### Nerdctl setup #############################################################
###############################################################################

sudo dnf install -y nerdctl

# TODO: are these necessary? What do they do?
sudo dnf install -y device-mapper-persistent-data lvm2

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
elif [ "$BINARY_BUCKET_REGION" = "us-iso-east-1" ] || [ "$BINARY_BUCKET_REGION" = "us-iso-west-1" ]; then
  S3_DOMAIN="c2s.ic.gov"
elif [ "$BINARY_BUCKET_REGION" = "us-isob-east-1" ]; then
  S3_DOMAIN="sc2s.sgov.gov"
elif [ "$BINARY_BUCKET_REGION" = "eu-isoe-west-1" ]; then
  S3_DOMAIN="cloud.adc-e.uk"
elif [ "$BINARY_BUCKET_REGION" = "us-isof-south-1" ]; then
  S3_DOMAIN="csp.hci.ic.gov"
fi
S3_URL_BASE="https://$BINARY_BUCKET_NAME.s3.$BINARY_BUCKET_REGION.$S3_DOMAIN/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/linux/$ARCH"
S3_PATH="s3://$BINARY_BUCKET_NAME/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/linux/$ARCH"

BINARIES=(
  kubelet
)
for binary in ${BINARIES[*]}; do
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
  sudo chown root:root $binary
  sudo mv $binary /usr/bin/
done

sudo rm ./*.sha256

kubelet --version > "${WORKING_DIR}/kubelet-version.txt"
sudo mv "${WORKING_DIR}/kubelet-version.txt" /etc/eks/kubelet-version.txt

sudo systemctl enable ebs-initialize-bin@kubelet

################################################################################
### ECR Credential Provider Binary #############################################
################################################################################

ECR_CREDENTIAL_PROVIDER_BINARY="ecr-credential-provider"

if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
  echo "AWS cli present - using it to copy ${ECR_CREDENTIAL_PROVIDER_BINARY} from s3."
  aws s3 cp --region $BINARY_BUCKET_REGION $S3_PATH/$ECR_CREDENTIAL_PROVIDER_BINARY .
else
  echo "AWS cli missing - using wget to fetch ${ECR_CREDENTIAL_PROVIDER_BINARY} from s3. Note: This won't work for private bucket."
  sudo wget "$S3_URL_BASE/$ECR_CREDENTIAL_PROVIDER_BINARY"
fi

sudo chmod +x $ECR_CREDENTIAL_PROVIDER_BINARY
sudo mkdir -p /etc/eks/image-credential-provider
sudo mv $ECR_CREDENTIAL_PROVIDER_BINARY /etc/eks/image-credential-provider/

################################################################################
### SSM Agent ##################################################################
################################################################################

if dnf list installed | grep amazon-ssm-agent; then
  echo "amazon-ssm-agent already present - skipping install"
else
  if ! [[ -z "${SSM_AGENT_VERSION}" ]]; then
    echo "Installing amazon-ssm-agent@${SSM_AGENT_VERSION} from S3"
    sudo dnf install -y https://s3.${BINARY_BUCKET_REGION}.${S3_DOMAIN}/amazon-ssm-${BINARY_BUCKET_REGION}/${SSM_AGENT_VERSION}/linux_${ARCH}/amazon-ssm-agent.rpm
  else
    echo "Installing amazon-ssm-agent from AL core repository"
    sudo dnf install -y amazon-ssm-agent
  fi
fi

################################################################################
### AMI Metadata ###############################################################
################################################################################

BASE_AMI_ID=$($WORKING_DIR/shared/bin/imds /latest/meta-data/ami-id)
cat << EOF | sudo tee /etc/eks/release
BASE_AMI_ID="$BASE_AMI_ID"
BUILD_TIME="$(date)"
BUILD_KERNEL="$(uname -r)"
ARCH="$(uname -m)"
EOF
sudo chown -R root:root /etc/eks

################################################################################
### Remove Update from cloud-init config #######################################
################################################################################

sudo sed -i \
  's/ - package-update-upgrade-install/# Removed so that nodes do not have version skew based on when the node was started.\n# - package-update-upgrade-install/' \
  /etc/cloud/cloud.cfg

# the CNI results cache is not valid across reboots, and errant files can prevent cleanup of pod sandboxes
# https://github.com/containerd/containerd/issues/8197
# this was fixed in 1.2.x of libcni but containerd < 2.x are using libcni 1.1.x
sudo systemctl enable cni-cache-reset
