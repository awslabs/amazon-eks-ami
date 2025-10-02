# Examples

---

## Merging multiple configuration objects

When using the IMDS configuration source (`--config-source=imds://user-data`),
`nodeadm` will merge any configuration objects it discovers before configuring your node.

With the following user data:
```
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: my-cluster
    apiServerEndpoint: https://example.com
    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=
    cidr: 10.100.0.0/16

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  kubelet:
    config:
      shutdownGracePeriod: 30s
      featureGates:
        DisableKubeletCloudCredentialProviders: true

--BOUNDARY--
```

The configuration `nodeadm` will use is:
```
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: my-cluster
    apiServerEndpoint: https://example.com
    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=
    cidr: 10.100.0.0/16
  kubelet:
    config:
      shutdownGracePeriod: 30s
      featureGates:
        DisableKubeletCloudCredentialProviders: true
```

The configuration objects will be merged in the order they appear in the MIME multi-part document, meaning the value in the lattermost configuration object will take precedence.

---
## Using instance ID as node name

When the `InstanceIdNodeName` feature gate is enabled, `nodeadm` will use the EC2 instance's ID (e.g. `i-abcdefg1234`) as the name of the `Node` object created by `kubelet`, instead of the EC2 instance's private DNS Name (e.g. `ip-192-168-1-1.ec2.internal`).
There are several benefits of doing this:
1. Your `Node` names are more meaningful in, for example, the output of `kubectl get nodes`.
2. The `Node` name, which is in the critical path of `kubelet` authentication, is non-volatile. While the private DNS name of an instance may change, its ID cannot.
3. The `ec2:DescribeInstances` permission can be removed from your node role's IAM policy; this is no longer necessary.

### To enable this feature, you will need to:
1. [Create a new worker node IAM role](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html#create-worker-node-role)
    - ⚠️ **Note**: you should create a new role when migrating an existing cluster to avoid authentication failures on existing nodes.
2. Configure authorization for the role using username `system:node:{{SessionName}}`, for example by [creating an access entry](https://docs.aws.amazon.com/eks/latest/userguide/creating-access-entries.html) of type `EC2` for the new role:
    -  ⚠️ **Note**: you can still use the [legacy `aws-auth` ConfigMap](https://docs.aws.amazon.com/eks/latest/userguide/auth-configmap.html#aws-auth-users) to grant access, but services like [EKS Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) will require the use of access entries.
```
aws eks create-access-entry \
  --cluster-name $CLUSTER_NAME \
  --principal-arn $ROLE_CREATED_ABOVE \
  --type EC2
```

3. Enable the feature gate in your user data:
```
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  featureGates:
    InstanceIdNodeName: true
```

---
## Enabling fast image pull (experimental)

When the `FastImagePull` feature gate is enabled, `nodeadm` will configure the container runtime to pull and unpack container images in parallel.

This has the benefit of potentially decreasing image pull time, at the cost of increased CPU, memory and EBS usage during image pull.

⚠️ **Note**: This flag will be ignored on instance sizes below a certain vCPU and memory threshold.

### To enable this feature:
1. Ensure your instance type is a larger instance type. Currently we recommend a 2xlarge instance or larger, but that value may change.
2. Make sure your workloads can tolerate the increased CPU and memory usage during image pull. This makes the most sense when you need to pull a very large container image early in a node's lifecycle, before other workloads are running.
3. Ensure you've configured additional EBS throughput for your instance root volume. We recommend at least 600MiB/s throughput. Below that value, you may see longer image pull times with this flag. Higher values up to 1000MiB/s and 16k IOPs may result in better performance.
4. Enable the feature gate in your user data:
```
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  featureGates:
    FastImagePull: true
```

---

## Configuring `containerd`

Additional `containerd` configuration can be supplied in your `NodeConfig`. The values in your inline TOML document will overwrite any default value set by `nodeadm`.

The following configuration object:
```
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster: ...
  containerd:
    config: |
      [plugins."io.containerd.grpc.v1.cri".containerd]
      discard_unpacked_layers = false
```

Can be used to disable deletion of unpacked image layers in the `containerd` content store.

---

## Modifying container RLIMITs

If your workload requires different RLIMITs than the defaults, you can use the `baseRuntimeSpec` option of `containerd` to override them:

```
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster: ...
  containerd:
    baseRuntimeSpec:
      process:
        rlimits:
          - type: RLIMIT_NOFILE
            soft: 1024
            hard: 1024
```

---

## Defining a Max Pods Expression

Under certain circumstances, the desired max pods value for a given node or instance type can diverge from the
default calculation. Since the use of a static `NodeConfig` is encouraged as the input source for nodeadm, nodeadm
accepts a `maxPodsExpression` to determine the final `maxPods` value passed to kubelet. This string is interpreted
as a [CEL](https://cel.dev/overview/cel-overview) expression with three variables set in the environment:

* `default_enis` - the maximum number of network interfaces attachable on the default network card
* `ips_per_eni` - the maximum number of IPv4 addresses attachable to a single interface
* `max_pods` - the standard `maxPods` for the current instance type. This can be equivalently expressed in CEL as `(default_enis * (ips_per_eni - 1)) + 2`

⚠️ **Note**: These values will vary between instance types and may require `ec2:DescribeInstanceTypes` API calls. Expressions should be tested to confirm desired outputs before final use in the intended environment.

Some common use cases:

1. Offset the final `maxPods` value to account for known host networking pods
   * e.g. `max_pods + 2` to allow two additional pods
2. Limit the final `maxPods` value to a fixed value
   * e.g. `max_pods < 30 ? max_pods : 30`
3. Limit the number of ENIs that can be used for pods
   * e.g. `((default_enis - 3) * (ips_per_eni - 1)) + 2` to reserve three ENIs
   * For instances utilizing the [AWS VPC CNI's Custom Networking](https://docs.aws.amazon.com/eks/latest/userguide/cni-custom-network.html) feature, reserving a single ENI may be necessary

```yaml
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster: ...
  kubelet:
    maxPodsExpression: "((default_enis - 1) * (ips_per_eni - 1)) + 2"
```
⚠️ **Note**: Values set for `maxPods` in the `kubelet` config will take precedence over the result of the `maxPodsExpression`. `kubeReserved` will be calculated using the result of the expression or
the internally calculated max pods value, if the expression cannot be evaluated.