# Amazon EKS AMI Build Specification

This repository contains resources and configuration scripts for building a
custom Amazon EKS AMI with [HashiCorp Packer](https://www.packer.io/). This is
the same configuration that Amazon EKS uses to create the official Amazon
EKS-optimized AMI.

## Setup

You must have [Packer](https://www.packer.io/) installed on your local system.
For more information, see [Installing Packer](https://www.packer.io/docs/install/index.html)
in the Packer documentation. You must also have AWS account credentials
configured so that Packer can make calls to AWS API operations on your behalf.
For more information, see [Authentication](https://www.packer.io/docs/builders/amazon.html#specifying-amazon-credentials)
in the Packer documentation.

**Note**
The default instance type to build this AMI is an `m4.large` and does not
qualify for the AWS free tier. You are charged for any instances created
when building this AMI.

## Building the AMI

A Makefile is provided to build the AMI, but it is just a small wrapper around
invoking Packer directly. You can initiate the build process by running the
following command in the root of this repository:

```bash
make
```

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

## Security

For security issues or concerns, please do not open an issue or pull request on GitHub. Please report any suspected or confirmed security issues to AWS Security https://aws.amazon.com/security/vulnerability-reporting/

## License Summary

This sample code is made available under a modified MIT license. See the LICENSE file.
