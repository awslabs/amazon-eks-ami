# Amazon EKS AMI Build Specification

This repository contains resources and configuration scripts for building a
custom Amazon EKS AMI with [HashiCorp Packer](https://www.packer.io/). This is
the same configuration that Amazon EKS uses to create the official Amazon
EKS-optimized AMI.

## Setup

You must have [Packer](https://www.packer.io/) version 1.8.0 or later installed on your local system.
For more information, see [Installing Packer](https://www.packer.io/docs/install/index.html)
in the Packer documentation. You must also have AWS account credentials
configured so that Packer can make calls to AWS API operations on your behalf.
For more information, see [Authentication](https://www.packer.io/docs/builders/amazon.html#specifying-amazon-credentials)
in the Packer documentation.

**Note**
The default instance type to build this AMI does not qualify for the AWS free tier. You are charged for any instances created
when building this AMI.

## Building the AMI

A Makefile is provided to build the Amazon EKS Worker AMI, but it is just a small wrapper around
invoking Packer directly. You can initiate the build process by running the
following command in the root of this repository:

```bash
make
```
The Makefile chooses a particular kubelet binary to use per kubernetes version which you can [view here](Makefile).
To build an Amazon EKS Worker AMI for a particular Kubernetes version run the following command
```bash
make 1.23 ## Build a Amazon EKS Worker AMI for k8s 1.23
```
### Building against other versions of Kubernetes binaries
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

### AMI template variables

Default values for most variables are defined in [a default variable file](eks-worker-al2-variables.json).

Users have the following options for specifying their own values:

1. Provide a variable file with the `PACKER_VARIABLE_FILE` argument to `make`. Values in this file will override values in the default variable file. Your variable file does not need to include all possible variables, as it will be merged with the default variable file.
2. Pass a key-value pair for any template variable to `make`. These values will override any values specified using the first method.

**Note** that some variables (such as `arch` and `kubernetes_version`) do not have a sensible, static default, and are satisfied by the Makefile. Such variables do not appear in the default variable file, and must be overridden (if necessary) by the second method described above.

### Providing your own Kubernetes Binaries

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

## Using the AMI

If you are just getting started with Amazon EKS, we recommend that you follow
our [Getting Started](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
chapter in the Amazon EKS User Guide. If you already have a cluster, and you
want to launch a node group with your new AMI, see [Launching Amazon EKS Worker
Nodes](https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html)
in the Amazon EKS User Guide.

## AL2 / Linux Kernel Information

By default, the `amazon-eks-ami` uses a [source_ami_filter](https://github.com/awslabs/amazon-eks-ami/blob/e3f1b910f83ad1f27e68312e50474ea6059f052d/eks-worker-al2.json#L46) that selects the latest [hvm](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html) AL2 AMI for the given architecture as the base AMI. For more information on what kernel versions are running on published Amazon EKS optimized Linux AMIs, see [the public documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html).

When building an AMI, you can set the `kernel_version` to `4.14` or `5.4` to customize the kernel version. The [upgrade_kernel.sh script](https://github.com/awslabs/amazon-eks-ami/blob/master/scripts/upgrade_kernel.sh#L26) contains the logic for updating and upgrading the kernel. For Kubernetes versions 1.18 and below, it uses the `4.14` kernel if not set, and it will install the latest patches. For Kubernetes version 1.19 and above, it uses the `5.4` kernel if not set.

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

## Security

For security issues or concerns, please do not open an issue or pull request on GitHub. Please report any suspected or confirmed security issues to AWS Security https://aws.amazon.com/security/vulnerability-reporting/

## License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.
