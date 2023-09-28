#!/usr/bin/env bash

# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/install-nvidia-driver.html
# --> GRID drivers (G5, G4dn, and G3 instances) --> Amazon Linux and Amazon Linux 2
sudo yum update -y
sudo yum install -y gcc kernel-devel-$(uname -r)

#https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html#centos7

sudo yum install -y tar bzip2

# make automake gcc gcc-c++ pciutils elfutils-libelf-devel libglvnd-devel iptables firewalld vim bind-utils wget
# sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# distribution=rhel7
# ARCH=$( /bin/arch )
# sudo yum-config-manager --add-repo http://developer.download.nvidia.com/compute/cuda/repos/$distribution/${ARCH}/cuda-$distribution.repo
# sudo yum install -y nvidia-driver-latest-dkms

sudo rm -rf /usr/lib64/libnvidia-ml.so /usr/lib64/libnvidia-ml.so.1 /usr/bin/nvidia-smi/


# aws s3 cp --recursive s3://ec2-linux-nvidia-drivers/latest/ .
wget https://us.download.nvidia.com/tesla/535.104.12/NVIDIA-Linux-x86_64-535.104.12.run
chmod +x NVIDIA-Linux-x86_64-535.104.12.run
sudo CC=/usr/bin/gcc10-cc ./NVIDIA-Linux-x86_64-535.104.12.run --install-libglvnd --no-questions --disable-nouveau  --no-backup  --ui=none 


sudo touch /etc/modprobe.d/nvidia.conf
echo "options nvidia NVreg_EnableGpuFirmware=0" | sudo tee --append /etc/modprobe.d/nvidia.conf


# cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
# net.bridge.bridge-nf-call-iptables  = 1
# net.ipv4.ip_forward                 = 1
# net.bridge.bridge-nf-call-ip6tables = 1
# EOF


#https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html#id6
sudo mkdir -p /etc/containerd \
    && sudo containerd config default | sudo tee /etc/containerd/config.toml




# cat <<EOF > containerd-config.patch
# --- config.toml.orig    2020-12-18 18:21:41.884984894 +0000
# +++ /etc/containerd/config.toml 2020-12-18 18:23:38.137796223 +0000
# @@ -94,6 +94,15 @@
#         privileged_without_host_devices = false
#         base_runtime_spec = ""
#         [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
# +            SystemdCgroup = true
# +       [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
# +          privileged_without_host_devices = false
# +          runtime_engine = ""
# +          runtime_root = ""
# +          runtime_type = "io.containerd.runc.v1"
# +          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
# +            BinaryName = "/usr/bin/nvidia-container-runtime"
# +            SystemdCgroup = true
#     [plugins."io.containerd.grpc.v1.cri".cni]
#     bin_dir = "/opt/cni/bin"
#     conf_dir = "/etc/cni/net.d"
# EOF



distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
    && curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo



sudo yum install nvidia-container-toolkit -y

cat <<EOF | sudo tee -a "/etc/containerd/config.toml"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
privileged_without_host_devices = false
runtime_engine = ""
runtime_root = ""
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
BinaryName = "/usr/bin/nvidia-container-runtime"
EOF

sudo sed -i 's/default_runtime_name = "runc"/default_runtime_name = "nvidia"/' "/etc/containerd/config.toml"



# sudo systemctl restart containerd
