# Amazon EKS AMI Build Specification

This repository contains resources and configuration scripts for building a
custom EKS AMI with [HashiCorp Packer](https://www.packer.io/). This is based
on the [same configuration](https://github.com/awslabs/amazon-eks-ami) that
Amazon EKS uses to create the official Amazon EKS-optimized AMI.

## Differences from Official AMI

The file `CHANGELOG_AMS.md` in the project root contains the list of changes
made in this fork. The overarching aim of these changes is stability. Most
notably, this uses [Ubuntu 18.04](http://releases.ubuntu.com/18.04/)
instead of [Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/).  Because
Ubuntu uses ext4 rather than xfs, it avoids the [disk corruption](https://github.com/awslabs/amazon-eks-ami/issues/51)
issue affecting the official AMI. Likewise, setting up Docker log rotation
prevents worker nodes from [failing due to full disks.](https://github.com/awslabs/amazon-eks-ami/issues/36)

## Setup

You must have [Packer](https://www.packer.io/) installed on your local system.
For more information, see [Installing Packer](https://www.packer.io/docs/install/index.html)
in the Packer documentation. You must also have AWS account credentials
configured so that Packer can make calls to AWS API operations on your behalf.
For more information, see [Authentication](https://www.packer.io/docs/builders/amazon.html#specifying-amazon-credentials)
in the Packer documentation.

## Building the AMI

A Makefile is provided to build the AMI, but it is just a small wrapper around
invoking Packer directly. You can initiate the build process by running the
following command in the root of this repository:

**For a new version**

1. Take a look at the upstream for this repo and try to integrate the changes.
2. Switch the all to the version you want to build.
3. Push to the repo, the master branch will be built by Jenkins


The Makefile runs Packer with the `eks-worker-bionic.json` build specification
template and the [amazon-ebs](https://www.packer.io/docs/builders/amazon-ebs.html)
builder. An instance is launched and the Packer [Shell
Provisioner](https://www.packer.io/docs/provisioners/shell.html) runs the
`install-worker.sh` script on the instance to install software and perform other
necessary configuration tasks.  Then, Packer creates an AMI from the instance
and terminates the instance after the AMI is created.

## Using the AMI

The [EKS Terraform module](https://github.com/AdvMicrogrid/terraform-aws-eks)
simplifies deployment of infrastructure for an EKS cluster.

If you are just getting started with Amazon EKS, we recommend that you follow
our [Getting Started](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
chapter in the Amazon EKS User Guide. If you already have a cluster, and you
want to launch a node group with your new AMI, see [Launching Amazon EKS Worker
Nodes](https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html)
in the Amazon EKS User Guide.

The [`amazon-eks-nodegroup.yaml`](amazon-eks-nodegroup.yaml) AWS CloudFormation
template in this repository is provided to launch a node group with the new AMI
ID that is returned when Packer finishes building. Note that there is important
Amazon EC2 user data in this CloudFormation template that bootstraps the worker
nodes when they are launched so that they can register with your Amazon EKS
cluster. Your nodes cannot register properly without this user data.

### Compatibility with CloudFormation Template

The CloudFormation template for EKS Nodes is published in the S3 bucket
`amazon-eks` under the path `cloudformation`. You can see a list of previous
versions by running `aws s3 ls s3://amazon-eks/cloudformation/`.

| CloudFormation Version | EKS AMI versions                           | [amazon-vpc-cni-k8s](https://github.com/aws/amazon-vpc-cni-k8s/releases) |
| ---------------------- | ------------------------------------------ | -------------------- |
| 2019-09-27             | amazon-eks-node-(1.14,1.13,1.12,1.11)-v20190927 | v1.5.4
| 2019-09-17             | amazon-eks-node-(1.14,1.13,1.12,1.11)-v20190906 | v1.5.3
| 2019-02-11             | amazon-eks-node-(1.12,1.11,1.10)-v20190327 | v1.3.2 (for p3dn.24xlarge instances) |
| 2019-02-11             | amazon-eks-node-(1.11,1.10)-v20190220      | v1.3.2 (for p3dn.24xlarge instances) |
| 2019-02-11             | amazon-eks-node-(1.11,1.10)-v20190211      | v1.3.2 (for p3dn.24xlarge instances) |
| 2018-12-10             | amazon-eks-node-(1.11,1.10)-v20181210      | v1.2.1 |
| 2018-11-07             | amazon-eks-node-v25+                       | v1.2.1 (for t3 and r5 instances) |
| 2018-08-30             | amazon-eks-node-v23+                       | v1.1.0 |
| 2018-08-21             | amazon-eks-node-v23+                       | v1.1.0 |

For older versions of the EKS AMI (v20-v22), you can find the CloudFormation
templates in the same bucket under the path `s3://amazon-eks/1.10.3/2018-06-05/`.

## AL2 / Linux Kernel Information

By default, the `amazon-eks-ami` uses a [source_ami_filter](https://github.com/awslabs/amazon-eks-ami/blob/e3f1b910f83ad1f27e68312e50474ea6059f052d/eks-worker-al2.json#L46) that selects the latest [hvm](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html) AL2 AMI for the given architecture as the base AMI. For more information on what kernel versions are running on published Amazon EKS optimized Linux AMIs, see [the public documentation](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html).

When building an AMI, you can set the `kernel_version` to `4.14` or `5.4` to customize the kernel version. The [upgrade_kernel.sh script](https://github.com/awslabs/amazon-eks-ami/blob/master/scripts/upgrade_kernel.sh#L26) contains the logic for updating and upgrading the kernel. For Kubernetes versions 1.18 and below, it uses the `4.14` kernel if not set, and it will install the latest patches. For Kubernetes version 1.19 and above, it uses the `5.4` kernel if not set.

## Security

For security issues or concerns, please do not open an issue or pull request on GitHub. Please report any suspected or confirmed security issues to AWS Security https://aws.amazon.com/security/vulnerability-reporting/

## License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.
