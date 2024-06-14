# AMI templates

## Variables

Templates are defined for each OS distribution, each with variables whose defaults depend on specified Kubernetes version.

Users have the following options for specifying their own values:

1. Provide a variable file with the `PACKER_VARIABLE_FILE` argument to `make`. Values in this file will override values in the default variable file. Your variable file does not need to include all possible variables, as it will be merged with the default variable file.
2. Pass a key-value pair for any template variable to `make`. These values will override any values that were specified with the first method.

> **Note**
> Some variables (such as `arch` and `kubernetes_version`) do not have a sensible, static default, and are satisfied by the Makefile.
> Such variables do not appear in the default variable file, and must be overridden (if necessary) by a method described above.

---

## Kubernetes binaries

When building the AMI, binaries such as `kubelet`, `aws-iam-authenticator`, and `ecr-credential-provider` are installed.

### Using the latest

It is recommended that the latest available binaries are used, as they may contain important fixes for bugs or security issues.
The latest binaries can be discovered with the following script:
```bash
hack/latest-binaries.sh $KUBERNETES_MINOR_VERSION
```
This script will return the values for the binary-related AMI template variables, for example:
```bash
> hack/latest-binaries.sh 1.28

kubernetes_version=1.28.1 kubernetes_build_date=2023-10-01
```

### Using a specific version

Use the following commands to obtain values for the binary-related AMI template variables:
```bash
# List Kubernetes versions
aws s3 ls s3://amazon-eks

# List build dates
aws s3 ls s3://amazon-eks/1.23.9/

# List platforms
aws s3 ls s3://amazon-eks/1.23.9/2022-07-27/bin/

# List architectures
aws s3 ls s3://amazon-eks/1.23.9/2022-07-27/bin/linux/

# List binaries
aws s3 ls s3://amazon-eks/1.23.9/2022-07-27/bin/linux/x86_64/
```

To build using the example binaries above:
```bash
make k8s \
  kubernetes_version=1.23.9 \
  kubernetes_build_date=2022-07-27 \
  arch=x86_64
```

### Providing your own

By default, binaries are downloaded from the public S3 bucket `amazon-eks` in `us-west-2`.
You can instead provide your own version of Kubernetes binaries.

To use your own binaries:

1. Copy all of the necessary binaries to your own S3 bucket using the AWS CLI. For example:
```bash
 aws s3 cp kubelet s3://$BUCKET/$KUBERNETES_VERSION/$KUBERNETES_BUILD_DATE/bin/linux/$ARCH/kubelet
```

**Important**: You must provide all the binaries present in the default `amazon-eks` bucket for a specific `KUBERNETES_VERSION`, `KUBERNETES_BUILD_DATE`, and `ARCH` combination.
These binaries must be accessible using the credentials on the Packer builder EC2 instance.

2. Run the following command to start the build process to use your own Kubernetes binaries:
```bash
make k8s \
  binary_bucket_name=my-custom-bucket \
  binary_bucket_region=eu-west-1 \
  kubernetes_version=1.14.9 \
  kubernetes_build_date=2020-01-22
```
**Note**: Confirm that the binary_bucket_name, binary_bucket_region, kubernetes_version, and kubernetes_build_date parameters match the path to your binaries in Amazon S3.

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
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::amazon-eks/*",
                "arn:aws:s3:::amazon-eks"
            ]
        }
    ]
}
```

You will need to use the region you are building the AMI in to specify the ECR repository resource in the second IAM statement. You may also need to change the account if you are building the AMI in a different partition or special region. You can see a mapping of regions to account ID [here](https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html).
If you're using a custom s3 bucket to vend different K8s binaries, you will need to change the resource in the third IAM statement above to reference your custom bucket.
For more information about the permissions required by Packer with different configurations, see the [docs](https://www.packer.io/plugins/builders/amazon#iam-task-or-instance-role).

---

## Image credential provider plugins

Prior to Kubernetes 1.27, the `kubelet` could obtain credentials for ECR out of the box. This legacy credential process has been removed in Kubernetes 1.27, and
ECR credentials should now be obtained via a plugin, the `ecr-credential-provider`. This plugin is installed in the AMI at `/etc/eks/image-credential-provider/ecr-credential-provider`. More information about this plugin is available in the [`cloud-provider-aws` documentation](https://cloud-provider-aws.sigs.k8s.io/credential_provider/).

Additional image credential provider plugins may be appended to `/etc/eks/image-credential-provider/config.json`. In Kubernetes versions 1.26 and below, all plugins in this file must support `credentialprovider.kubelet.k8s.io/v1alpha1`. In Kubernetes versions 1.27 and above, they must support `credentialprovider.kubelet.k8s.io/v1`.

For more information about image credential provider plugins, refer to the [Kubernetes documentation](https://kubernetes.io/docs/tasks/administer-cluster/kubelet-credential-provider/).
