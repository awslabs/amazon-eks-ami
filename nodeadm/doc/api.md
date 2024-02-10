# API Reference

## Packages
- [node.eks.aws/v1alpha1](#nodeeksawsv1alpha1)

## node.eks.aws/v1alpha1

### Resource Types
- [NodeConfig](#nodeconfig)

#### ClusterDetails

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `name` _string_ |  |
| `apiServerEndpoint` _string_ |  |
| `certificateAuthority` _[byte](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#byte-v1-meta) array_ |  |
| `cidr` _string_ |  |
| `enableOutpost` _boolean_ |  |
| `id` _string_ |  |

#### ContainerdOptions

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `config` _string_ | Config is an inline containerd config toml document that can be provided by the user to override default generated configurations https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md |

#### KubeletOptions

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `config` _object (keys:string, values:RawExtension)_ | Config is a kubelet config that can be provided by the user to override default generated configurations https://kubernetes.io/docs/reference/config-api/kubelet-config.v1/ |
| `flags` _string array_ | Flags is a list of command-line kubelet arguments. These arguments are amended to the generated defaults, and therefore will act as overrides https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/ |

#### NodeConfig

NodeConfig is the Schema for the nodeconfigs API

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
