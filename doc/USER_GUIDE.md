# User Guide

This document includes details about using the AMI template and the resulting AMIs.

1. [AMI template variables](#ami-template-variables)
1. [Building against other versions of Kubernetes binaries](#building-against-other-versions-of-kubernetes-binaries)
1. [Providing your own Kubernetes binaries](#providing-your-own-kubernetes-binaries)
1. [Container image caching](#container-image-caching)
1. [IAM permissions](#iam-permissions)
1. [Customizing kubelet config](#customizing-kubelet-config)
1. [AL2 and Linux kernel information](#al2-and-linux-kernel-information)
1. [Updating known instance types](#updating-known-instance-types)
1. [Version-locked packages](#version-locked-packages)

---

## AMI template variables

Default values for most variables are defined in [a default variable file](eks-worker-al2-variables.json).

Users have the following options for specifying their own values:

1. Provide a variable file with the `PACKER_VARIABLE_FILE` argument to `make`. Values in this file will override values in the default variable file. Your variable file does not need to include all possible variables, as it will be merged with the default variable file.
2. Pass a key-value pair for any template variable to `make`. These values will override any values that were specified with the first method.

**Note** that some variables (such as `arch` and `kubernetes_version`) do not have a sensible, static default, and are satisfied by the Makefile. Such variables do not appear in the default variable file, and must be overridden (if necessary) by the second method described above.

---

## Building against other versions of Kubernetes binaries
To build an Amazon EKS Worker AMI with other versions of Kubernetes that are not listed above run the following AWS Command
Line Interface (AWS CLI) commands to obtain values for KUBERNETES_VERSION, KUBERNETES_BUILD_DATE, PLATFORM, ARCH from S3
```bash
#List of all avalable Kuberenets Versions:
aws s3 ls s3://amazon-eks 
KUBERNETES_VERSION=1.23.9 # Chose a version and set the variable

#List of all builds for the specified Kubernetes Version:
aws s3 ls s3://amazon-eks/$KUBERNETES_VERSION/
KUBERNETES_BUILD_DATE=2022-07-27 # Chose a date and set the variable

#List of all platforms available for the selected Kubernetes Version and build date
aws s3 ls s3://amazon-eks/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/
PLATFORM=linux # Chose a platform and set the variable

#List of all architectures for the selected Kubernetes Version, build date and platform
aws s3 ls s3://amazon-eks/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/linux/
ARCH=x86_64 #Chose an architecture and set the variable
```
Run the following command to build an Amazon EKS Worker AMI based on the chosen parameters in the previous step
```bash
make k8s \
  kubernetes_version=$KUBERNETES_VERSION \
  kubernetes_build_date=$KUBERNETES_BUILD_DATE \
  arch=$ARCH
```

---

## Providing your own Kubernetes Binaries

By default, binaries are downloaded from the Amazon EKS public Amazon Simple Storage Service (Amazon S3)
bucket amazon-eks in us-west-2. You can instead choose to provide your own version of Kubernetes binaries to be used. To use your own binaries

1. Copy the binaries to your own S3 bucket using the AWS CLI. Here is an example that uses Kubelet binary
```bash
 aws s3 cp kubelet s3://my-custom-bucket/kubernetes_version/kubernetes_build_date/bin/linux/arch/kubelet
```
**Note**: Replace my-custom-bucket, amazon-eks, kubernetes_version, kubernetes_build_date, and arch with your values.

**Important**: You must provide all the binaries listed in the default amazon-eks bucket for a specific kubernetes_version, kubernetes_build_date, and arch combination. These binaries must be accessible through AWS Identity and Access Management (IAM) credentials configured in the Install and configure HashiCorp Packer section.

2. Run the following command to start the build process to use your own Kubernetes binaries
```bash
make k8s \
  binary_bucket_name=my-custom-bucket \
  binary_bucket_region=eu-west-1 \
  kubernetes_version=1.14.9 \
  kubernetes_build_date=2020-01-22
```
**Note**: Confirm that the binary_bucket_name, binary_bucket_region, kubernetes_version, and kubernetes_build_date parameters match the path to your binaries in Amazon S3.

The Makefile runs Packer with the `eks-worker-al2.json` build specification
template and the [amazon-ebs](https://www.packer.io/docs/builders/amazon-ebs.html)
builder. An instance is launched and the Packer [Shell
Provisioner](https://www.packer.io/docs/provisioners/shell.html) runs the
`install-worker.sh` script on the instance to install software and perform other
necessary configuration tasks.  Then, Packer creates an AMI from the instance
and terminates the instance after the AMI is created.

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
 - 602401143452.dkr.ecr.<AWS_REGION>.amazonaws.com/eks/pause:3.5
 - 602401143452.dkr.ecr.<AWS_REGION>.amazonaws.com/amazon-k8s-cni-init:<default and latest>
 - 602401143452.dkr.ecr.<AWS_REGION>.amazonaws.com/amazon-k8s-cni:<default and latest>

The account ID can be different depending on the region and partition you are building the AMI in. See [here](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html) for more details.

Since the VPC CNI is not versioned with K8s itself, the latest version of the VPC CNI and the default version, based on the response from the EKS DescribeAddonVersions at the time of the AMI build, will be cached. 

The images listed above are also tagged with each region in the partition the AMI is built in, since images are often built in one region and copied to others within the same partition. Images that are available to pull from an ECR FIPS endpoint are also tagged as such (i.e. `602401143452.dkr.ecr-fips.us-east-1.amazonaws.com/eks/pause:3.5`).

When listing images on a node, you'll notice a long list of images. However, most of these images are simply tagged in different ways with no storage overhead. Images cached in the AMI total around 1.0 GiB. In general, a node with no images cached using the VPC CNI will use around 500 MiB of images when in a `Ready` state with no other pods running on the node.

---

## IAM Permissions

To build the EKS Optimized AMI, you will need the following permissions:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CopyImage",
                "ec2:CreateImage",
                "ec2:CreateKeypair",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSnapshot",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:DeleteKeyPair",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSnapshot",
                "ec2:DeleteVolume",
                "ec2:DeregisterImage",
                "ec2:DescribeImageAttribute",
                "ec2:DescribeImages",
                "ec2:DescribeInstances",
                "ec2:DescribeInstanceStatus",
                "ec2:DescribeRegions",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSubnets",
                "ec2:DescribeTags",
                "ec2:DescribeVolumes",
                "ec2:DetachVolume",
                "ec2:GetPasswordData",
                "ec2:ModifyImageAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifySnapshotAttribute",
                "ec2:RegisterImage",
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:TerminateInstances",
                "eks:DescribeAddonVersions",
                "ecr:GetAuthorizationToken"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchGetImage",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer"
            ],
            "Resource": "arn:aws:ecr:us-west-2:602401143452:repository/*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::amazon-eks/*"
        }
    ]
}
```

You will need to use the region you are building the AMI in to specify the ECR repository resource in the second IAM statement. You may also need to change the account if you are building the AMI in a different partition or special region. You can see a mapping of regions to account ID [here](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html).
If you're using a custom s3 bucket to vend different K8s binaries, you will need to change the resource in the third IAM statement above to reference your custom bucket.
For more information about the permissions required by Packer with different configurations, see the [docs](https://www.packer.io/plugins/builders/amazon#iam-task-or-instance-role).

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
2. [bootstrap.sh](https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh) does modify a few fields, like `kubeReserved` and `evictionHard`, so you'd need to modify the config after the bootstrap script is run and restart `kubelet` to overwrite those properties.

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

## AL2 and Linux Kernel Information

By default, the `amazon-eks-ami` uses a [source_ami_filter](https://github.com/awslabs/amazon-eks-ami/blob/e3f1b910f83ad1f27e68312e50474ea6059f052d/eks-worker-al2.json#L46) that selects the latest [hvm](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html) AL2 AMI for the given architecture as the base AMI. For more information on what kernel versions are running on published Amazon EKS optimized Linux AMIs, see [the public documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html).

When building an AMI, you can set `kernel_version` to customize the kernel version. Valid values are:
- `4.14`
- `5.4`
- `5.10`

If `kernel_version` is not set:
- For Kubernetes 1.23 and below, `5.4` is used.
- For Kubernetes 1.24 and above, `5.10` is used.

The [upgrade_kernel.sh script](../scripts/upgrade_kernel.sh) contains the logic for updating and upgrading the kernel.

---

## Updating known instance types

`files/bootstrap.sh` configures the maximum number of pods on a node based off of the number of ENIs available, which is determined by the instance type. Larger instances generally have more ENIs. The number of ENIs limits how many IPV4 addresses are available on an instance, and we need one IP address per pod. You can [see this file](https://github.com/aws/amazon-vpc-cni-k8s/blob/master/scripts/gen_vpc_ip_limits.go) for the code that calculates the max pods for more information.

To add support for new instance types, at a minimum, we need to update `files/eni-max-pods.txt` using the [amazon-vpc-cni-k8s package.](https://github.com/aws/amazon-vpc-cni-k8s) to set the number of max pods available for those instance types. If the instance type is not on the list, `bootstrap.sh` will fail when the node is started.

```
$ git clone git@github.com:aws/amazon-vpc-cni-k8s.git

# AWS credentials required at this point
$ make generate-limits
# misc/eni-max-pods.txt should be generated

# Copy the generated file to this repo, something like this:
$ cp misc/eni-max-pods.txt ../amazon-eks-ami/files/

# Verify that expected types were added
$ git diff
```

At this point, you can build an AMI and it will include the updated list of instance types.

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
