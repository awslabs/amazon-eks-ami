# Amazon Linux 2

## Template variables

<!-- template-variable-table-boundary -->
| Variable | Description |
| - | - |
| `additional_yum_repos` |  |
| `ami_component_description` |  |
| `ami_description` |  |
| `ami_name` |  |
| `ami_regions` |  |
| `ami_users` |  |
| `arch` |  |
| `associate_public_ip_address` |  |
| `aws_access_key_id` |  |
| `aws_region` |  |
| `aws_secret_access_key` |  |
| `aws_session_token` |  |
| `binary_bucket_name` |  |
| `binary_bucket_region` |  |
| `cache_container_images` |  |
| `cni_plugin_version` |  |
| `containerd_version` |  |
| `creator` |  |
| `docker_version` | Docker is not installed on Kubernetes v1.25+ |
| `enable_fips` | Install openssl and enable fips related kernel parameters |
| `encrypted` |  |
| `iam_instance_profile` | The name of an IAM instance profile to launch the EC2 instance with. |
| `instance_type` |  |
| `kernel_version` |  |
| `kms_key_id` |  |
| `kubernetes_build_date` |  |
| `kubernetes_version` |  |
| `launch_block_device_mappings_volume_size` |  |
| `pause_container_version` |  |
| `pull_cni_from_github` |  |
| `remote_folder` | Directory path for shell provisioner scripts on the builder instance |
| `runc_version` |  |
| `security_group_id` |  |
| `source_ami_filter_name` |  |
| `source_ami_id` |  |
| `source_ami_owners` |  |
| `ssh_interface` | If using ```session_manager```, you need to specify a non-minimal ami as the minimal version does not have the SSM agent installed. |
| `ssh_username` |  |
| `ssm_agent_version` | Version of the SSM agent to install from the S3 bucket provided by the SSM agent project, such as ```latest```. If empty, the latest version of the SSM agent available in the Amazon Linux core repositories will be installed. |
| `subnet_id` |  |
| `temporary_security_group_source_cidrs` |  |
| `user_data_file` | Path to a file that will be used for the user data when launching the instance. |
| `volume_type` |  |
| `working_dir` | Directory path for ephemeral resources on the builder instance |
<!-- template-variable-table-boundary -->

---

## Container Image Caching

Optionally, some container images can be cached during the AMI build process in order to reduce the latency of the node getting to a `Ready` state when launched.

To turn on container image caching:

```
cache_container_images=true make 1.23
```

When container image caching is enabled, the following images are cached:
 - 602401143452.dkr.ecr.<AWS_REGION>.amazonaws.com/eks/kube-proxy:<default and latest>-eksbuild.<BUILD_VERSION>
 - 602401143452.dkr.ecr.<AWS_REGION>.amazonaws.com/eks/kube-proxy:<default and latest>-minimal-eksbuild.<BUILD_VERSION>
 - 602401143452.dkr.ecr.<AWS_REGION>.amazonaws.com/amazon-k8s-cni-init:<default and latest>
 - 602401143452.dkr.ecr.<AWS_REGION>.amazonaws.com/amazon-k8s-cni:<default and latest>

The account ID can be different depending on the region and partition you are building the AMI in. See [here](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html) for more details.

Since the VPC CNI is not versioned with K8s itself, the latest version of the VPC CNI and the default version, based on the response from the EKS DescribeAddonVersions at the time of the AMI build, will be cached.

The images listed above are also tagged with each region in the partition the AMI is built in, since images are often built in one region and copied to others within the same partition. Images that are available to pull from an ECR FIPS endpoint are also tagged as such (i.e. `602401143452.dkr.ecr-fips.us-east-1.amazonaws.com/eks/pause:3.5`).

When listing images on a node, you'll notice a long list of images. However, most of these images are simply tagged in different ways with no storage overhead. Images cached in the AMI total around 1.0 GiB. In general, a node with no images cached using the VPC CNI will use around 500 MiB of images when in a `Ready` state with no other pods running on the node.

---

## Customizing Kubelet Config

In some cases, customers may want to customize the [kubelet configuration](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/#kubelet-config-k8s-io-v1beta1-KubeletConfiguration) on their nodes, and there are two mechanisms to do that with the EKS Optimized AMI.

**Set the "--kubelet-extra-args" flag when invoking bootstrap.sh**

`bootstrap.sh`, the script that bootstraps nodes when using the EKS Optimized AMI, supports a flag called `--kubelet-extra-args` that allows you to pass in additional `kubelet` configuration. If you invoke the bootstrap script yourself (self-managed nodegroups or EKS managed nodegroups with custom AMIs), you can use that to customize your configuration. For example, you can use something like the following in your userdata:

```
/etc/eks/bootstrap.sh my-cluster --kubelet-extra-args '--registry-qps=20 --registry-burst=40'
```

In this case, it will set `registryPullQPS` to 20 and `registryBurst` to 40 in `kubelet`. Some of the flags, like the ones above, are marked as deprecated and you're encouraged to set them in the `kubelet` config file (described below), but they continue to work as of 1.23.

**Update the kubelet config file**

You can update the `kubelet` config file directly with new configuration. On EKS Optimized AMIs, the file is stored at `/etc/kubernetes/kubelet/kubelet-config.json`. It must be valid JSON. You can use a utility like `jq` (or your tool of choice) to edit the config in your user data:

```
echo "$(jq ".registryPullQPS=20 | .registryBurst=40" /etc/kubernetes/kubelet/kubelet-config.json)" > /etc/kubernetes/kubelet/kubelet-config.json
```

There are a couple of important caveats here:

1. If you update the `kubelet` config file after `kubelet` has already started (i.e. `bootstrap.sh` already ran), you'll need to restart `kubelet` to pick up the latest configuration.
2. [bootstrap.sh](https://github.com/awslabs/amazon-eks-ami/blob/main/templates/al2/runtime/bootstrap.sh) does modify a few fields, like `kubeReserved` and `evictionHard`, so you'd need to modify the config after the bootstrap script is run and restart `kubelet` to overwrite those properties.

**View active kubelet config**

When `kubelet` starts up, it logs all possible flags, including unset flags. The unset flags get logged with default values. *These logs do not necessarily reflect the actual active configuration.* This has caused confusion in the past when customers have configured the `kubelet` config file with one value and notice the default value is logged. Here is an example of the referenced log:

```
Aug 16 21:53:49 ip-192-168-92-220.us-east-2.compute.internal kubelet[3935]: I0816 21:53:49.202824    3935 flags.go:59] FLAG: --registry-burst="10"
Aug 16 21:53:49 ip-192-168-92-220.us-east-2.compute.internal kubelet[3935]: I0816 21:53:49.202829    3935 flags.go:59] FLAG: --registry-qps="5"
```

To view the actual `kubelet` config on your node, you can use the Kubernetes API to confirm that your configuration has applied.

```
$ kubectl proxy
$ curl -sSL "http://localhost:8001/api/v1/nodes/ip-192-168-92-220.us-east-2.compute.internal/proxy/configz" | jq

{
  "kubeletconfig": {
    ...
    "registryPullQPS": 20,
    "registryBurst": 40,
    ...
  }
}
```

---

## Customizing Containerd Config

The EKS defaults for `containerd` will be written to `/etc/containerd/config.toml`.
Additional configuration files placed in the `/etc/containerd/config.d/` directory will be imported and override defaults as described in the [`containerd` documentation](https://github.com/containerd/containerd/blob/release/1.7/docs/man/containerd-config.toml.5.md).

> **NOTE**: If you create an additional configuration file after `containerd`
> has already started (i.e. `bootstrap.sh` has already executed), you'll need to
> restart `containerd` to pick up the latest configuration.

> **CAUTION**: Making direct edits to the EKS default `containerd` configuration file is not recommended.

**View active containerd config**

To see the final configuration that is produced and consumed by containerd, you
can use the containerd cli:
```
$ containerd config dump
...
```

---

## Ephemeral Storage

Some instance types launch with ephemeral NVMe instance storage (i3, i4i, c5d, c6id, etc). There are two main ways of utilizing this storage within Kubernetes: a single RAID-0 array for use by kubelet and containerd or mounting the individual disks for pod usage.

The EKS Optimized AMI includes a utility script to configure ephemeral storage. The script can be invoked by passing the `--local-disks <raid0 | mount>` flag to the `/etc/eks/bootstrap.sh` script or the script can be invoked directly at `/bin/setup-local-disks`. All disks are formatted with an XFS file system.

Below are details on the two disk setup options:

### RAID-0 for Kubelet and Containerd (raid0)

A RAID-0 array is setup that includes all ephemeral NVMe instance storage disks. The containerd and kubelet state directories (`/var/lib/containerd` and `/var/lib/kubelet`) will then use the ephemeral storage for more and faster node ephemeral-storage. The node's ephemeral storage can be shared among pods that request ephemeral storage and container images that are downloaded to the node.

### Mount for Persistent Volumes (mount)

Another way of utilizing the ephemeral disks is to format and mount the individual disks. Mounting individual disks allows the [local-static-provisioner](https://github.com/kubernetes-sigs/sig-storage-local-static-provisioner) DaemonSet to create Persistent Volume Claims that pods can utilize.

### Experimental: RAID-10 Kubelet and Containerd (raid10)

Similar to RAID-0 array, it is possible to utilize RAID-10 array for instance types with four or more ephemeral NVMe instance storage disks. RAID-10 tolerates failure of maximum of 2 disks. However, individual ephemeral disks can not be replaced, so the purpose of redundancy is to make graceful decommisioning of a node possible.

RAID-10 can be enabled by passing `--local-disks raid10` flag to the bootstrap script.

---

## Version-locked packages

Some packages are critical for correct, performant behavior of a Kubernetes node; such as:
- `kernel`
- `containerd`
- `runc`

> **Note**
> This is not an exhaustive list. The complete list of locked packages is available with `yum versionlock list`.

As a result, these packages should generally be modified within the bounds of a managed process that gracefully handles failures and prevents disruption to the cluster's workloads.

To prevent unintentional changes, the [yum-versionlock](https://github.com/rpm-software-management/yum-utils/tree/05db7ef501fc9d6698935bcc039c83c0761c3be2/plugins/versionlock) plugin is used on these packages.

If you wish to modify a locked package, you can:
```
# unlock a single package
sudo yum versionlock delete $PACKAGE_NAME

# unlock all packages
sudo yum versionlock clear
```
