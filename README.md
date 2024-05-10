# MongoDB FedRAMP Documentation

To find the proper build-date for a given Kubernetes version, run a variant of the following:
```
aws s3 ls --profile xgen-prod s3://amazon-eks/1.27.12/
```

To build an AWS EKS AMI for a given Kubernetes version, run a variant of the following:
```
enable_fips=true aws_region=us-gov-west-1 kubernetes_version=1.27.12 kubernetes_build_date=2024-04-19 arch=x86_64 make build
```

To upload the AMI to gov environments, run a variant of the following:
```
aws ec2 modify-image-attribute --image-id <ami-xxxxxxxxxxxx> --launch-permission "Add=[{OrganizationArn=arn:aws-us-gov:organizations::255955262727:organization/o-swvi5bpd85}]"
```

# Amazon EKS AMI Build Specification

This repository contains resources and configuration scripts for building a
custom Amazon EKS AMI with [HashiCorp Packer](https://www.packer.io/). This is
the same configuration that Amazon EKS uses to create the official Amazon
EKS-optimized AMI.

**Check out the [📖 documentation](https://awslabs.github.io/amazon-eks-ami/) to learn more.**

---

## 🚀 Getting started

If you are new to Amazon EKS, we recommend that you follow
our [Getting Started](https://docs.aws.amazon.com/eks/latest/userguide/getting-started.html)
chapter in the Amazon EKS User Guide. If you already have a cluster, and you
want to launch a node group with your new AMI, see [Launching Amazon EKS Worker
Nodes](https://docs.aws.amazon.com/eks/latest/userguide/launch-workers.html).

## 🔢 Pre-requisites

You must have [Packer](https://www.packer.io/) version 1.8.0 or later installed on your local system.
For more information, see [Installing Packer](https://www.packer.io/docs/install/index.html)
in the Packer documentation. You must also have AWS account credentials
configured so that Packer can make calls to AWS API operations on your behalf.
For more information, see [Authentication](https://www.packer.io/docs/builders/amazon.html#specifying-amazon-credentials)
in the Packer documentation.

## 👷 Building the AMI

A Makefile is provided to build the Amazon EKS Worker AMI, but it is just a small wrapper around
invoking Packer directly. You can initiate the build process by running the
following command in the root of this repository:

```bash
# build an AMI with the latest Kubernetes version and the default OS distro
make

# build an AMI with a specific Kubernetes version and the default OS distro
make k8s=1.29

# build an AMI with a specific Kubernetes version and a specific OS distro
make k8s=1.29 os_distro=al2023

# check default value and options in help doc
make help
```

The Makefile chooses a particular kubelet binary to use per Kubernetes version which you can [view here](Makefile).

> **Note**
> The default instance type to build this AMI does not qualify for the AWS free tier.
> You are charged for any instances created when building this AMI.

## 🔒 Security

For security issues or concerns, please do not open an issue or pull request on GitHub. Please report any suspected or confirmed security issues to AWS Security https://aws.amazon.com/security/vulnerability-reporting/

## ⚖️ License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.
