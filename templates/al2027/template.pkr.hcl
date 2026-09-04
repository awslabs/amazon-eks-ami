# Avoid mixing go templating calls ( for example ```{{ upper(`string`) }}``` )
# and HCL2 calls (for example '${ var.string_value_example }' ). They won't be
# executed together and the outcome will be unknown.

# See https://www.packer.io/docs/templates/hcl_templates/blocks/packer for more info
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

# All generated input variables will be of 'string' type as this is how Packer JSON
# views them; you can change their type later on. Read the variables type
# constraints documentation
# https://www.packer.io/docs/templates/hcl_templates/variables#type-constraints for more info.
variable "ami_component_description" {
  type    = string
  default = ""
}

variable "ami_description" {
  type = string
}

variable "ami_name" {
  type = string
}

variable "ami_regions" {
  type = string
}

variable "ami_users" {
  type = string
}

variable "arch" {
  type = string
}

variable "associate_public_ip_address" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "binary_bucket_name" {
  type = string
}

variable "binary_bucket_region" {
  type = string
}

variable "containerd_version" {
  type = string
}

variable "creator" {
  type    = string
  default = env("USER")
}

variable "custom_endpoint_ec2" {
  type = string
}

variable "enable_accelerator" {
  type = string
}

variable "enable_efa" {
  type = string
}

variable "enable_fips" {
  type = string
}

variable "enable_nvidia_gdrcopy_driver" {
  type = string
}

variable "encrypted" {
  type = string
}

variable "iam_instance_profile" {
  type = string
}

variable "install_containerd_from_s3" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "kms_key_id" {
  type = string
}

variable "kubernetes_build_date" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "launch_block_device_mappings_volume_size" {
  type = string
}

variable "nodeadm_build_image" {
  type = string
}

variable "nvidia_driver_major_version" {
  type = string
}

variable "nvidia_gdrcopy_driver_version" {
  type = string
}

variable "nvidia_grid_runfile_bucket_name" {
  type = string
}

variable "nvidia_repository_url" {
  type = string
}

variable "pause_container_image" {
  type = string
}

variable "remote_folder" {
  type = string
}

variable "runc_version" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "source_ami_filter_name" {
  type = string
}

variable "source_ami_id" {
  type = string
}

variable "source_ami_owners" {
  type = string
}

variable "ssh_interface" {
  type = string
}

variable "ssh_username" {
  type = string
}

variable "ssm_agent_version" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "temporary_key_pair_type" {
  type    = string
  default = "ed25519"
}

variable "temporary_security_group_source_cidrs" {
  type = string
}

variable "user_data_file" {
  type = string
}

variable "volume_type" {
  type = string
}

variable "working_dir" {
  type    = string
  default = ""
}


locals {
  # Was: "(k8s: {{ user `kubernetes_version` }}, containerd: {{ user `containerd_version` }})"
  ami_component_description = coalesce(var.ami_component_description, "(k8s: ${var.kubernetes_version}, containerd: ${var.containerd_version})")
  # Was: "{{user `remote_folder`}}/worker"
  working_dir = coalesce(var.working_dir, "${var.remote_folder}/worker")
}

# source blocks are generated from your builders; a source can be referenced in
# build blocks. A build block runs provisioner and post-processors on a
# source. Read the documentation for source blocks here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/source
source "amazon-ebs" "al2023" {
  ami_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    volume_size           = 20
    volume_type           = "${var.volume_type}"
  }
  ami_description             = "${var.ami_description}, ${local.ami_component_description}"
  ami_name                    = "${var.ami_name}"
  ami_regions                 = compact(split(",", var.ami_regions))
  ami_users                   = compact(split(",", var.ami_users))
  associate_public_ip_address = var.associate_public_ip_address == "" ? null : var.associate_public_ip_address
  aws_polling {
    delay_seconds = 30
    max_attempts  = 480
  }
  custom_endpoint_ec2  = "${var.custom_endpoint_ec2}"
  encrypt_boot         = "${var.encrypted}"
  iam_instance_profile = "${var.iam_instance_profile}"
  instance_type        = "${var.instance_type}"
  kms_key_id           = "${var.kms_key_id}"
  launch_block_device_mappings {
    delete_on_termination = true
    device_name           = "/dev/xvda"
    volume_size           = "${var.launch_block_device_mappings_volume_size}"
    volume_type           = "${var.volume_type}"
  }
  metadata_options {
    http_tokens = "required"
  }
  region = "${var.aws_region}"
  run_tags = {
    creator = "${var.creator}"
  }
  security_group_id = "${var.security_group_id}"
  snapshot_users    = compact(split(",", var.ami_users))
  source_ami        = var.source_ami_id
  source_ami_filter {
    filters = {
      architecture        = var.arch
      name                = var.source_ami_filter_name
      root-device-type    = "ebs"
      state               = "available"
      virtualization-type = "hvm"
    }
    owners      = [var.source_ami_owners]
    most_recent = true
  }
  ssh_interface = "${var.ssh_interface}"
  ssh_pty       = true
  ssh_username  = "${var.ssh_username}"
  subnet_id     = "${var.subnet_id}"
  tags = {
    Name               = "${var.ami_name}"
    build_region       = "{{ .BuildRegion }}"
    containerd_version = "${var.containerd_version}"
    created            = "{{timestamp}}"
    kubernetes         = "${var.kubernetes_version}/${var.kubernetes_build_date}/bin/linux/${var.arch}"
    source_ami_id      = "{{ .SourceAMI }}"
    source_ami_name    = "{{ .SourceAMIName }}"
    ssm_agent_version  = "${var.ssm_agent_version}"
  }
  temporary_security_group_source_cidrs = compact(split(",", var.temporary_security_group_source_cidrs))
  user_data_file                        = "${var.user_data_file}"
}

# a build block invokes sources and runs provisioning steps on them. The
# documentation for build blocks can be found here:
# https://www.packer.io/docs/templates/hcl_templates/blocks/build
build {
  sources = ["source.amazon-ebs.al2023"]

  provisioner "shell" {
    inline = ["mkdir -p ${local.working_dir}/rootfs", "mkdir -p ${local.working_dir}/bin", "mkdir -p ${local.working_dir}/log-collector-script", "mkdir -p ${local.working_dir}/nodeadm", "mkdir -p ${local.working_dir}/gpu"]
  }

  provisioner "file" {
    destination = "${local.working_dir}/bin"
    source      = "${path.root}/runtime/bin/"
  }

  provisioner "file" {
    destination = "${local.working_dir}/gpu"
    source      = "${path.root}/runtime/gpu/"
  }

  provisioner "file" {
    destination = "${local.working_dir}/rootfs"
    source      = "${path.root}/runtime/rootfs/"
  }

  provisioner "file" {
    destination = "${local.working_dir}/log-collector-script/"
    source      = "${path.root}/../../log-collector-script/linux/"
  }

  provisioner "shell" {
    inline = ["sudo mkdir -p /etc/eks/log-collector-script/", "sudo cp -v ${local.working_dir}/log-collector-script/eks-log-collector.sh /etc/eks/log-collector-script/"]
  }

  provisioner "file" {
    destination = "${local.working_dir}/nodeadm"
    source      = "${path.root}/../../nodeadm/"
  }

  provisioner "shell" {
    inline = ["sudo cp -rv ${local.working_dir}/rootfs/* /"]
  }

  provisioner "shell" {
    inline = ["sudo chmod -R a+x ${local.working_dir}/bin/", "sudo cp -rv ${local.working_dir}/bin/* /usr/bin/", "sudo chmod -R a+x ${local.working_dir}/gpu/*"]
  }

  provisioner "shell" {
    remote_folder = "${var.remote_folder}"
    script        = "${path.root}/provisioners/set-clocksource.sh"
  }

  provisioner "shell" {
    environment_vars = ["ENABLE_FIPS=${var.enable_fips}"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/enable-fips.sh"
  }

  provisioner "shell" {
    environment_vars  = ["ENABLE_EFA=${var.enable_efa}"]
    expect_disconnect = true
    script            = "${path.root}/provisioners/limit-c-states.sh"
  }

  provisioner "shell" {
    environment_vars = ["BINARY_BUCKET_NAME=${var.binary_bucket_name}", "BINARY_BUCKET_REGION=${var.binary_bucket_region}", "CONTAINERD_VERSION=${var.containerd_version}", "INSTALL_CONTAINERD_FROM_S3=${var.install_containerd_from_s3}", "KUBERNETES_BUILD_DATE=${var.kubernetes_build_date}", "KUBERNETES_VERSION=${var.kubernetes_version}", "RUNC_VERSION=${var.runc_version}", "SSM_AGENT_VERSION=${var.ssm_agent_version}", "WORKING_DIR=${local.working_dir}"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/install-worker.sh"
  }

  provisioner "shell" {
    environment_vars = ["AWS_REGION=${var.aws_region}", "BUILD_IMAGE=${var.nodeadm_build_image}", "PROJECT_DIR=${local.working_dir}/nodeadm"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/install-nodeadm.sh"
  }

  provisioner "shell" {
    environment_vars = ["AWS_REGION=${var.aws_region}", "PAUSE_CONTAINER_IMAGE=${var.pause_container_image}"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/cache-pause-container.sh"
  }

  provisioner "shell" {
    environment_vars = ["AWS_REGION=${var.aws_region}", "ENABLE_ACCELERATOR=${var.enable_accelerator}", "WORKING_DIR=${local.working_dir}"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/install-neuron-driver.sh"
  }

  provisioner "shell" {
    environment_vars = ["AWS_REGION=${var.aws_region}", "ENABLE_ACCELERATOR=${var.enable_accelerator}", "BINARY_BUCKET_NAME=${var.binary_bucket_name}", "BINARY_BUCKET_REGION=${var.binary_bucket_region}", "NVIDIA_DRIVER_MAJOR_VERSION=${var.nvidia_driver_major_version}", "NVIDIA_REPOSITORY=${var.nvidia_repository_url}", "EC2_GRID_DRIVER_S3_BUCKET=${var.nvidia_grid_runfile_bucket_name}", "ENABLE_NVIDIA_GDRCOPY_DRIVER=${var.enable_nvidia_gdrcopy_driver}", "NVIDIA_GDRCOPY_DRIVER_VERSION=${var.nvidia_gdrcopy_driver_version}", "WORKING_DIR=${local.working_dir}"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/install-nvidia-driver.sh"
  }

  provisioner "shell" {
    environment_vars = ["AWS_REGION=${var.aws_region}", "BINARY_BUCKET_NAME=${var.binary_bucket_name}", "BINARY_BUCKET_REGION=${var.binary_bucket_region}", "ENABLE_ACCELERATOR=${var.enable_accelerator}", "ENABLE_EFA=${var.enable_efa}", "WORKING_DIR=${local.working_dir}"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/install-efa.sh"
  }

  provisioner "shell" {
    remote_folder = "${var.remote_folder}"
    script        = "${path.root}/provisioners/cleanup.sh"
  }

  provisioner "shell" {
    environment_vars = ["ENABLE_ACCELERATOR=${var.enable_accelerator}"]
    remote_folder    = "${var.remote_folder}"
    script           = "${path.root}/provisioners/validate.sh"
  }

  provisioner "shell" {
    execute_command = "chmod +x {{ .Path }}; {{ .Path }} ${local.working_dir}/version-info.json"
    remote_folder   = "${var.remote_folder}"
    script          = "${path.root}/provisioners/generate-version-info.sh"
  }

  provisioner "file" {
    destination = "${var.ami_name}-version-info.json"
    direction   = "download"
    source      = "${local.working_dir}/version-info.json"
  }

  provisioner "shell" {
    inline = ["sudo rm -rf ${local.working_dir}"]
  }

  provisioner "shell" {
    remote_folder = "${var.remote_folder}"
    script        = "${path.root}/provisioners/configure-selinux.sh"
  }

  post-processor "manifest" {
    custom_data = {
      source_ami_id   = "${build.SourceAMI}"
      source_ami_name = "${build.SourceAMIName}"
    }
    output     = "manifest.json"
    strip_path = true
  }
  post-processor "manifest" {
    custom_data = {
      source_ami_id   = "${build.SourceAMI}"
      source_ami_name = "${build.SourceAMIName}"
    }
    output     = "${var.ami_name}-manifest.json"
    strip_path = true
  }
}
