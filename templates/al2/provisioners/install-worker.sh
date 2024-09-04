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
validate_env_set CACHE_CONTAINER_IMAGES
validate_env_set CNI_PLUGIN_VERSION
validate_env_set CONTAINERD_VERSION
validate_env_set DOCKER_VERSION
validate_env_set KUBERNETES_BUILD_DATE
validate_env_set KUBERNETES_VERSION
validate_env_set PAUSE_CONTAINER_VERSION
validate_env_set PULL_CNI_FROM_GITHUB
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

sudo yum install -y \
  yum-utils \
  yum-plugin-versionlock

# lock the version of the kernel and associated packages before we yum update
sudo yum versionlock kernel-$(uname -r) kernel-headers-$(uname -r) kernel-devel-$(uname -r)

# Update the OS to begin with to catch up to the latest packages.
sudo yum update -y

# Install necessary packages
sudo yum install -y \
  aws-cfn-bootstrap \
  chrony \
  conntrack \
  curl \
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

# Remove any old kernel versions. `--count=1` here means "only leave 1 kernel version installed"
sudo package-cleanup --oldkernels --count=1 -y

# Remove the ec2-net-utils package, if it's installed. This package interferes with the route setup on the instance.
if yum list installed | grep ec2-net-utils; then sudo yum remove ec2-net-utils -y -q; fi

sudo mkdir -p /etc/eks/

################################################################################
### SSH ########################################################################
################################################################################

# Disable weak ciphers
echo -e "\nCiphers aes128-ctr,aes256-ctr,aes128-gcm@openssh.com,aes256-gcm@openssh.com" | sudo tee -a /etc/ssh/sshd_config
sudo systemctl restart sshd.service

################################################################################
### iptables ###################################################################
################################################################################

sudo mv $WORKING_DIR/iptables-restore.service /etc/eks/iptables-restore.service

################################################################################
### awscli #####################################################
################################################################################

### isolated regions can't communicate to awscli.amazonaws.com so installing awscli through yum
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
  sudo yum install -y awscli
fi

################################################################################
### systemd ####################################################################
################################################################################

sudo mv "${WORKING_DIR}/runtime.slice" /etc/systemd/system/runtime.slice
# this unit is safe to have regardless of variant because it will not run if
# the required binaries are not present.
sudo mv $WORKING_DIR/set-nvidia-clocks.service /etc/systemd/system/set-nvidia-clocks.service
sudo systemctl enable set-nvidia-clocks.service

# backporting removal of default dummy0 network interface in systemd v236
# https://github.com/systemd/systemd/blob/16ac586e5a77942bf1147bc9eae684d544ded88f/NEWS#L11139-L11144
cat << EOF | sudo tee /lib/modprobe.d/10-no-dummies.conf
options dummy numdummies=0
EOF

###############################################################################
### Containerd setup ##########################################################
###############################################################################

# install runc and lock version
sudo yum install -y runc-${RUNC_VERSION}
sudo yum versionlock runc-*

# install containerd and lock version
sudo yum install -y containerd-${CONTAINERD_VERSION}
sudo yum versionlock containerd-*

# install cri-tools for crictl, needed to interact with containerd's CRI server
sudo yum install -y cri-tools

sudo mkdir -p /etc/containerd/config.d
sudo mkdir -p /etc/eks/containerd
if [ -f "/etc/eks/containerd/containerd-config.toml" ]; then
  ## this means we are building a gpu ami and have already placed a containerd configuration file in /etc/eks
  echo "containerd config is already present"
else
  sudo mv $WORKING_DIR/containerd-config.toml /etc/eks/containerd/containerd-config.toml
fi

sudo mv $WORKING_DIR/kubelet-containerd.service /etc/eks/containerd/kubelet-containerd.service
sudo mv $WORKING_DIR/sandbox-image.service /etc/eks/containerd/sandbox-image.service
sudo mv $WORKING_DIR/pull-sandbox-image.sh /etc/eks/containerd/pull-sandbox-image.sh
sudo mv $WORKING_DIR/pull-image.sh /etc/eks/containerd/pull-image.sh
sudo chmod +x /etc/eks/containerd/pull-sandbox-image.sh
sudo chmod +x /etc/eks/containerd/pull-image.sh
sudo mkdir -p /etc/systemd/system/containerd.service.d
CONFIGURE_CONTAINERD_SLICE=$(vercmp "$KUBERNETES_VERSION" gteq "1.24.0" || true)
if [ "$CONFIGURE_CONTAINERD_SLICE" == "true" ]; then
  cat << EOF | sudo tee /etc/systemd/system/containerd.service.d/00-runtime-slice.conf
[Service]
Slice=runtime.slice
EOF
fi

cat << EOF | sudo tee /etc/systemd/system/containerd.service.d/10-compat-symlink.conf
[Service]
ExecStartPre=/bin/ln -sf /run/containerd/containerd.sock /run/dockershim.sock
EOF

cat << EOF | sudo tee -a /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

cat << EOF | sudo tee -a /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

###############################################################################
### Nerdctl setup #############################################################
###############################################################################

sudo yum install -y nerdctl
sudo mkdir -p /etc/nerdctl
cat << EOF | sudo tee -a /etc/nerdctl/nerdctl.toml
namespace = "k8s.io"
EOF

################################################################################
### Docker #####################################################################
################################################################################

sudo yum install -y device-mapper-persistent-data lvm2

if [[ ! -v "INSTALL_DOCKER" ]]; then
  INSTALL_DOCKER=$(vercmp "$KUBERNETES_VERSION" lt "1.25.0" || true)
else
  echo "WARNING: using override INSTALL_DOCKER=${INSTALL_DOCKER}. This option is deprecated and will be removed in a future release."
fi

if [[ "$INSTALL_DOCKER" == "true" ]]; then
  sudo amazon-linux-extras enable docker
  sudo groupadd -og 1950 docker
  sudo useradd --gid $(getent group docker | cut -d: -f3) docker

  # install docker and lock version
  sudo yum install -y docker-${DOCKER_VERSION}*
  sudo yum versionlock docker-*
  sudo usermod -aG docker $USER

  # Remove all options from sysconfig docker.
  sudo sed -i '/OPTIONS/d' /etc/sysconfig/docker

  sudo mkdir -p /etc/docker
  sudo mv $WORKING_DIR/docker-daemon.json /etc/docker/daemon.json
  sudo chown root:root /etc/docker/daemon.json

  # Enable docker daemon to start on boot.
  sudo systemctl daemon-reload
fi

################################################################################
### Logrotate ##################################################################
################################################################################

# kubelet uses journald which has built-in rotation and capped size.
# See man 5 journald.conf
sudo mv $WORKING_DIR/logrotate-kube-proxy /etc/logrotate.d/kube-proxy
sudo mv $WORKING_DIR/logrotate.conf /etc/logrotate.conf
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
  aws-iam-authenticator
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
  sudo mv $binary /usr/bin/
done

# Verify that the aws-iam-authenticator is at last v0.5.9 or greater. Otherwise, nodes will be
# unable to join clusters due to upgrading to client.authentication.k8s.io/v1beta1
iam_auth_version=$(sudo /usr/bin/aws-iam-authenticator version | jq -r .Version)
if vercmp "$iam_auth_version" lt "v0.5.9"; then
  # To resolve this issue, you need to update the aws-iam-authenticator binary. Using binaries distributed by EKS
  # with kubernetes_build_date 2022-10-31 or later include v0.5.10 or greater.
  echo "❌ The aws-iam-authenticator should be on version v0.5.9 or later. Found $iam_auth_version"
  exit 1
fi

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
sudo mv $WORKING_DIR/kubelet-kubeconfig /var/lib/kubelet/kubeconfig
sudo chown root:root /var/lib/kubelet/kubeconfig

# Inject CSIServiceAccountToken feature gate to kubelet config if kubernetes version starts with 1.20.
# This is only injected for 1.20 since CSIServiceAccountToken will be moved to beta starting 1.21.
if [[ $KUBERNETES_VERSION == "1.20"* ]]; then
  KUBELET_CONFIG_WITH_CSI_SERVICE_ACCOUNT_TOKEN_ENABLED=$(cat $WORKING_DIR/kubelet-config.json | jq '.featureGates += {CSIServiceAccountToken: true}')
  echo $KUBELET_CONFIG_WITH_CSI_SERVICE_ACCOUNT_TOKEN_ENABLED > $WORKING_DIR/kubelet-config.json
fi

# Enable Feature Gate for KubeletCredentialProviders in versions less than 1.28 since this feature flag was removed in 1.28.
# TODO: Remove this during 1.27 EOL
if vercmp $KUBERNETES_VERSION lt "1.28"; then
  KUBELET_CONFIG_WITH_KUBELET_CREDENTIAL_PROVIDER_FEATURE_GATE_ENABLED=$(cat $WORKING_DIR/kubelet-config.json | jq '.featureGates += {KubeletCredentialProviders: true}')
  echo $KUBELET_CONFIG_WITH_KUBELET_CREDENTIAL_PROVIDER_FEATURE_GATE_ENABLED > $WORKING_DIR/kubelet-config.json
fi

sudo mv $WORKING_DIR/kubelet.service /etc/systemd/system/kubelet.service
sudo chown root:root /etc/systemd/system/kubelet.service
sudo mv $WORKING_DIR/kubelet-config.json /etc/kubernetes/kubelet/kubelet-config.json
sudo chown root:root /etc/kubernetes/kubelet/kubelet-config.json

sudo systemctl daemon-reload
# Disable the kubelet until the proper dropins have been configured
sudo systemctl disable kubelet

################################################################################
### EKS ########################################################################
################################################################################

sudo mkdir -p /etc/eks
sudo mv $WORKING_DIR/get-ecr-uri.sh /etc/eks/get-ecr-uri.sh
sudo chmod +x /etc/eks/get-ecr-uri.sh
sudo mv $WORKING_DIR/eni-max-pods.txt /etc/eks/eni-max-pods.txt
sudo mv $WORKING_DIR/bootstrap.sh /etc/eks/bootstrap.sh
sudo chmod +x /etc/eks/bootstrap.sh
sudo mv $WORKING_DIR/max-pods-calculator.sh /etc/eks/max-pods-calculator.sh
sudo chmod +x /etc/eks/max-pods-calculator.sh

################################################################################
### ECR CREDENTIAL PROVIDER ####################################################
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
# ecr-credential-provider has support for public.ecr.aws in 1.27+
if vercmp "${KUBERNETES_VERSION}" gteq "1.27.0"; then
  ECR_CRED_PROVIDER_CONFIG_WITH_PUBLIC=$(cat $WORKING_DIR/ecr-credential-provider-config.json | jq '.providers[0].matchImages += ["public.ecr.aws"]')
  echo "${ECR_CRED_PROVIDER_CONFIG_WITH_PUBLIC}" > $WORKING_DIR/ecr-credential-provider-config.json
fi
sudo mv $WORKING_DIR/ecr-credential-provider-config.json /etc/eks/image-credential-provider/config.json

################################################################################
### Cache Images ###############################################################
################################################################################

if [[ "$CACHE_CONTAINER_IMAGES" == "true" ]] && ! [[ ${ISOLATED_REGIONS} =~ $BINARY_BUCKET_REGION ]]; then
  AWS_DOMAIN=$(imds 'latest/meta-data/services/domain')
  ECR_URI=$(/etc/eks/get-ecr-uri.sh "${BINARY_BUCKET_REGION}" "${AWS_DOMAIN}")

  sudo systemctl daemon-reload
  sudo systemctl start containerd
  sudo systemctl enable containerd

  K8S_MINOR_VERSION=$(echo "${KUBERNETES_VERSION}" | cut -d'.' -f1-2)

  #### Cache kube-proxy images starting with the addon default version and the latest version
  KUBE_PROXY_ADDON_VERSIONS=$(aws eks describe-addon-versions --addon-name kube-proxy --kubernetes-version=${K8S_MINOR_VERSION})
  KUBE_PROXY_IMGS=()
  if [[ $(jq '.addons | length' <<< $KUBE_PROXY_ADDON_VERSIONS) -gt 0 ]]; then
    DEFAULT_KUBE_PROXY_FULL_VERSION=$(echo "${KUBE_PROXY_ADDON_VERSIONS}" | jq -r '.addons[] .addonVersions[] | select(.compatibilities[] .defaultVersion==true).addonVersion')
    DEFAULT_KUBE_PROXY_VERSION=$(echo "${DEFAULT_KUBE_PROXY_FULL_VERSION}" | cut -d"-" -f1)
    DEFAULT_KUBE_PROXY_PLATFORM_VERSION=$(echo "${DEFAULT_KUBE_PROXY_FULL_VERSION}" | cut -d"-" -f2)

    LATEST_KUBE_PROXY_FULL_VERSION=$(echo "${KUBE_PROXY_ADDON_VERSIONS}" | jq -r '.addons[] .addonVersions[] .addonVersion' | sort -V | tail -n1)
    LATEST_KUBE_PROXY_VERSION=$(echo "${LATEST_KUBE_PROXY_FULL_VERSION}" | cut -d"-" -f1)
    LATEST_KUBE_PROXY_PLATFORM_VERSION=$(echo "${LATEST_KUBE_PROXY_FULL_VERSION}" | cut -d"-" -f2)

    KUBE_PROXY_IMGS=(
      ## Default kube-proxy images
      "${ECR_URI}/eks/kube-proxy:${DEFAULT_KUBE_PROXY_VERSION}-${DEFAULT_KUBE_PROXY_PLATFORM_VERSION}"
      "${ECR_URI}/eks/kube-proxy:${DEFAULT_KUBE_PROXY_VERSION}-minimal-${DEFAULT_KUBE_PROXY_PLATFORM_VERSION}"

      ## Latest kube-proxy images
      "${ECR_URI}/eks/kube-proxy:${LATEST_KUBE_PROXY_VERSION}-${LATEST_KUBE_PROXY_PLATFORM_VERSION}"
      "${ECR_URI}/eks/kube-proxy:${LATEST_KUBE_PROXY_VERSION}-minimal-${LATEST_KUBE_PROXY_PLATFORM_VERSION}"
    )
  fi

  #### Cache VPC CNI images starting with the addon default version and the latest version
  VPC_CNI_ADDON_VERSIONS=$(aws eks describe-addon-versions --addon-name vpc-cni --kubernetes-version=${K8S_MINOR_VERSION})
  VPC_CNI_IMGS=()
  if [[ $(jq '.addons | length' <<< $VPC_CNI_ADDON_VERSIONS) -gt 0 ]]; then
    DEFAULT_VPC_CNI_VERSION=$(echo "${VPC_CNI_ADDON_VERSIONS}" | jq -r '.addons[] .addonVersions[] | select(.compatibilities[] .defaultVersion==true).addonVersion')
    LATEST_VPC_CNI_VERSION=$(echo "${VPC_CNI_ADDON_VERSIONS}" | jq -r '.addons[] .addonVersions[] .addonVersion' | sort -V | tail -n1)
    CNI_IMG="${ECR_URI}/amazon-k8s-cni"
    CNI_INIT_IMG="${CNI_IMG}-init"

    VPC_CNI_IMGS=(
      ## Default VPC CNI Images
      "${CNI_IMG}:${DEFAULT_VPC_CNI_VERSION}"
      "${CNI_INIT_IMG}:${DEFAULT_VPC_CNI_VERSION}"

      ## Latest VPC CNI Images
      "${CNI_IMG}:${LATEST_VPC_CNI_VERSION}"
      "${CNI_INIT_IMG}:${LATEST_VPC_CNI_VERSION}"
    )
  fi

  CACHE_IMGS=(
    ${KUBE_PROXY_IMGS[@]:-}
    ${VPC_CNI_IMGS[@]:-}
  )
  PULLED_IMGS=()
  REGIONS=$(aws ec2 describe-regions --all-regions --output text --query 'Regions[].[RegionName]')

  for img in "${CACHE_IMGS[@]:-}"; do
    if [ -z "${img}" ]; then continue; fi
    ## only kube-proxy-minimal is vended for K8s 1.24+
    if [[ "${img}" == *"kube-proxy:"* ]] && [[ "${img}" != *"-minimal-"* ]] && vercmp "${K8S_MINOR_VERSION}" gteq "1.24"; then
      continue
    fi
    ## Since eksbuild.x version may not match the image tag, we need to decrement the eksbuild version until we find the latest image tag within the app semver
    eksbuild_version="1"
    if [[ ${img} == *'eksbuild.'* ]]; then
      eksbuild_version=$(echo "${img}" | grep -o 'eksbuild\.[0-9]\+' | cut -d'.' -f2)
    fi
    ## iterate through decrementing the build version each time
    for build_version in $(seq "${eksbuild_version}" -1 1); do
      img=$(echo "${img}" | sed -E "s/eksbuild.[0-9]+/eksbuild.${build_version}/")
      echo "Pulling image [${img}]"
      if /etc/eks/containerd/pull-image.sh "${img}"; then
        PULLED_IMGS+=("${img}")
        break
      elif [[ "${build_version}" -eq 1 ]]; then
        exit 1
      fi
    done
  done

  #### Tag the pulled down image for all other regions in the partition
  for region in ${REGIONS[*]}; do
    for img in "${PULLED_IMGS[@]:-}"; do
      if [ -z "${img}" ]; then continue; fi
      region_uri=$(/etc/eks/get-ecr-uri.sh "${region}" "${AWS_DOMAIN}")
      regional_img="${img/$ECR_URI/$region_uri}"
      sudo ctr -n k8s.io image tag "${img}" "${regional_img}" || :
      ## Tag ECR fips endpoint for supported regions
      if [[ "${region}" =~ (us-east-1|us-east-2|us-west-1|us-west-2|us-gov-east-1|us-gov-west-1) ]]; then
        regional_fips_img="${regional_img/.ecr./.ecr-fips.}"
        sudo ctr -n k8s.io image tag "${img}" "${regional_fips_img}" || :
        sudo ctr -n k8s.io image tag "${img}" "${regional_fips_img/-eksbuild.1/}" || :
      fi
      ## Cache the non-addon VPC CNI images since "v*.*.*-eksbuild.1" is equivalent to leaving off the eksbuild suffix
      if [[ "${img}" == *"-cni"*"-eksbuild.1" ]]; then
        sudo ctr -n k8s.io image tag "${img}" "${regional_img/-eksbuild.1/}" || :
      fi
    done
  done
fi

################################################################################
### SSM Agent ##################################################################
################################################################################

if yum list installed | grep amazon-ssm-agent; then
  echo "amazon-ssm-agent already present - skipping install"
else
  if ! [[ -z "${SSM_AGENT_VERSION}" ]]; then
    echo "Installing amazon-ssm-agent@${SSM_AGENT_VERSION} from S3"
    sudo yum install -y https://s3.${BINARY_BUCKET_REGION}.${S3_DOMAIN}/amazon-ssm-${BINARY_BUCKET_REGION}/${SSM_AGENT_VERSION}/linux_${ARCH}/amazon-ssm-agent.rpm
  else
    echo "Installing amazon-ssm-agent from AL core repository"
    sudo yum install -y amazon-ssm-agent
  fi
fi

################################################################################
### AMI Metadata ###############################################################
################################################################################

BASE_AMI_ID=$(imds /latest/meta-data/ami-id)
cat << EOF > "${WORKING_DIR}/release"
BASE_AMI_ID="$BASE_AMI_ID"
BUILD_TIME="$(date)"
BUILD_KERNEL="$(uname -r)"
ARCH="$(uname -m)"
EOF
sudo mv "${WORKING_DIR}/release" /etc/eks/release
sudo chown -R root:root /etc/eks

################################################################################
### Stuff required by "protectKernelDefaults=true" #############################
################################################################################

cat << EOF | sudo tee -a /etc/sysctl.d/99-amazon.conf
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
echo 'kernel.pid_max=4194304' | sudo tee -a /etc/sysctl.conf

################################################################################
### adding log-collector-script ################################################
################################################################################
sudo mkdir -p /etc/eks/log-collector-script/
sudo cp $WORKING_DIR/log-collector-script/eks-log-collector.sh /etc/eks/log-collector-script/

################################################################################
### Remove Yum Update from cloud-init config ###################################
################################################################################
sudo sed -i \
  's/ - package-update-upgrade-install/# Removed so that nodes do not have version skew based on when the node was started.\n# - package-update-upgrade-install/' \
  /etc/cloud/cloud.cfg
