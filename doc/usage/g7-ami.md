## Building a custom EKS-optimized AMI for G7 instances

G7 instances use NVIDIA Blackwell RTX PRO 4500 GPUs which require driver version 595 or later. The EKS-optimized accelerated AMI ships with driver version 580 by default, which does not support G7. To use G7 instances with EKS, you must build a custom AMI with driver version 595.

⚠️ **Note**: Driver version 595 is not compatible with P3, P3dn, and G6f instance types. Do not use a 595-based AMI for those instances.

### Prerequisites

- [Packer](https://www.packer.io/downloads) installed
- AWS credentials configured with permissions to create AMIs (EC2, S3 read access)
- Clone the EKS AMI repository:

```bash
git clone https://github.com/awslabs/amazon-eks-ami.git
cd amazon-eks-ami
```

### Build command

```bash
make k8s=1.32 os_distro=al2023 enable_accelerator=nvidia enable_efa=true nvidia_driver_major_version=595
```

This produces an AMI with NVIDIA 595 drivers suitable for G7 instances. The build pulls the driver from the [NVIDIA CUDA repository for AL2023](https://developer.download.nvidia.com/compute/cuda/repos/amzn2023/x86_64/).

The build takes approximately 15-25 minutes and outputs the AMI ID upon completion.

### Using the custom AMI with a managed node group

Create a launch template referencing your custom AMI, then attach it to your managed node group:

```bash
aws eks create-nodegroup \
  --cluster-name my-cluster \
  --nodegroup-name g7-nodes \
  --instance-types g7.48xlarge \
  --launch-template id=lt-xxxx,version=1
```

### Using the custom AMI with Karpenter

If you use Karpenter, create a dedicated EC2NodeClass and NodePool for instances using this AMI. Do not use this AMI with P3, P3dn, or G6f instances.

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: g7
spec:
  amiSelectorTerms:
    - id: ami-xxxx  # your custom 595 AMI ID
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: my-cluster
---
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: g7
spec:
  template:
    spec:
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: g7
      requirements:
        - key: node.kubernetes.io/instance-type
          operator: In
          values: ["g7.48xlarge"]
```

### Verifying GPU support

After launching a G7 instance with the custom AMI, verify the driver is loaded:

```bash
nvidia-smi
```

The output should show driver version 595.x and detect the RTX PRO 4500 GPU.

### Known limitations

- Driver 595 is not compatible with P3, P3dn, and G6f instances
- Driver 595 has known issues with EFA on GB200 instances
