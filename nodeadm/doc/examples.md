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

--BOUNDARY--
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
## Using instance ID as node name (experimental)

We introduced the ability to name nodes using their EC2 instance id instead of EC2 private DNS name for AL2023.

When the `InstanceIdNodeName` feature gate is enabled, `nodeadm` will use the EC2 instance's ID (e.g. `i-abcdefg1234`) as the name of the `Node` object created by `kubelet`, instead of the EC2 instance's private DNS Name (e.g. `ip-192-168-1-1.ec2.internal`).
There are several benefits of doing this:
1. Your `Node` names are more meaningful in, for example, the output of `kubectl get nodes`.
2. The `Node` name, which is in the critical path of `kubelet` authentication, is non-volatile. While the private DNS name of an instance may change, its ID cannot.
3. The `ec2:DescribeInstances` permission can be removed from your node role's IAM policy; this is no longer necessary.

To opt-in to the feature, you will need
- [Create new worker node IAM role](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html#create-worker-node-role)
- [Update the `aws-auth` ConfigMap with above created role](https://docs.aws.amazon.com/eks/latest/userguide/auth-configmap.html#aws-auth-users). See example below
```
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: <role_created_above>
  username: system:node:{{SessionName}}
```
- Enable the new feature gate `InstanceIdNodeName` in the user data, See example configuration below
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
  featureGates:
    InstanceIdNodeName: true
```
- [Create launch template with above user data](https://docs.aws.amazon.com/eks/latest/userguide/launch-templates.html).
- [Create the node group with launch template](https://docs.aws.amazon.com/eks/latest/userguide/create-managed-node-group.html).

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