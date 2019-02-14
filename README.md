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

```bash
make
```

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

## Security

For security issues or concerns, please do not open an issue or pull request on GitHub. Please report any suspected or confirmed security issues to AWS Security https://aws.amazon.com/security/vulnerability-reporting/

## License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.
