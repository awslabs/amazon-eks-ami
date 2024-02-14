# API Reference

## Packages
- [node.eks.aws/v1alpha1](#nodeeksawsv1alpha1)

## node.eks.aws/v1alpha1

### Resource Types
- [NodeConfig](#nodeconfig)

#### ClusterDetails

ClusterDetails contains the coordinates of your EKS cluster. These details can be found using the [DescribeCluster API](https://docs.aws.amazon.com/eks/latest/APIReference/API_DescribeCluster.html).

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `name` _string_ | Name is the name of your EKS cluster |
| `apiServerEndpoint` _string_ | APIServerEndpoint is the URL of your EKS cluster's kube-apiserver. |
| `certificateAuthority` _[byte](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#byte-v1-meta) array_ | CertificateAuthority is a base64-encoded string of your cluster's certificate authority chain. |
| `cidr` _string_ | CIDR is your cluster's Pod IP CIDR. This value is used to infer your cluster's DNS address. |
| `enableOutpost` _boolean_ | EnableOutpost determines how your node is configured when running on an AWS Outpost. |
| `id` _string_ | ID is an identifier for your cluster; this is only used when your node is running on an AWS Outpost. |

#### ContainerdOptions

ContainerdOptions are additional parameters passed to `containerd`.

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `config` _string_ | Config is inline [`containerd` configuration TOML](https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md) that will be [imported](https://github.com/containerd/containerd/blob/32169d591dbc6133ef7411329b29d0c0433f8c4d/docs/man/containerd-config.toml.5.md?plain=1#L146-L154) by the default configuration file. |

#### KubeletOptions

KubeletOptions are additional parameters passed to `kubelet`.

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `config` _object (keys:string, values:RawExtension)_ | Config is a [`KubeletConfiguration`](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1/) that will be merged with the defaults. |
| `flags` _string array_ | Flags are [command-line `kubelet`` arguments](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/). that will be appended to the defaults. |

#### NodeConfig

NodeConfig is the primary configuration object for `nodeadm`.

| Field | Description |
| --- | --- |
| `apiVersion` _string_ | `node.eks.aws/v1alpha1`
| `kind` _string_ | `NodeConfig`
| `kind` _string_ | Kind is a string value representing the REST resource this object represents. Servers may infer this from the endpoint the client submits requests to. Cannot be updated. In CamelCase. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds |
| `apiVersion` _string_ | APIVersion defines the versioned schema of this representation of an object. Servers should convert recognized schemas to the latest internal value, and may reject unrecognized values. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources |
| `metadata` _[ObjectMeta](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#objectmeta-v1-meta)_ | Refer to Kubernetes API documentation for fields of `metadata`. |
| `spec` _[NodeConfigSpec](#nodeconfigspec)_ |  |

#### NodeConfigSpec

_Appears in:_
- [NodeConfig](#nodeconfig)

| Field | Description |
| --- | --- |
| `cluster` _[ClusterDetails](#clusterdetails)_ |  |
| `kubelet` _[KubeletOptions](#kubeletoptions)_ |  |
| `containerd` _[ContainerdOptions](#containerdoptions)_ |  |
