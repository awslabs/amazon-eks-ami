## User Guide

This guide will provide more detailed usage information on this repo.

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
