# API Reference

## Packages
- [node.eks.aws/v1alpha1](#nodeeksawsv1alpha1)

## node.eks.aws/v1alpha1

### Resource Types
- [NodeConfig](#nodeconfig)

#### ClusterDetails

ClusterDetails contains the coordinates of your EKS cluster.
These details can be found using the [DescribeCluster API](https://docs.aws.amazon.com/eks/latest/APIReference/API_DescribeCluster.html).

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `name` _string_ | Name is the name of your EKS cluster |
| `apiServerEndpoint` _string_ | APIServerEndpoint is the URL of your EKS cluster's kube-apiserver. |
| `certificateAuthority` _integer array_ | CertificateAuthority is a base64-encoded string of your cluster's certificate authority chain. |
| `cidr` _string_ | CIDR is your cluster's service CIDR block. This value is used to infer your cluster's DNS address. |
| `enableOutpost` _boolean_ | EnableOutpost determines how your node is configured when running on an AWS Outpost. |
| `id` _string_ | ID is an identifier for your cluster; this is only used when your node is running on an AWS Outpost. |

#### ContainerdOptions

ContainerdOptions are additional parameters passed to `containerd`.

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `config` _string_ | Config is an inline [`containerd` configuration TOML](https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md)<br />that will be merged with the defaults. |
| `baseRuntimeSpec` _object (keys:string, values:[RawExtension](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#rawextension-runtime-pkg))_ | BaseRuntimeSpec is the OCI runtime specification upon which all containers will be based.<br />The provided spec will be merged with the default spec; so that a partial spec may be provided.<br />For more information, see: https://github.com/opencontainers/runtime-spec |

#### Feature

_Underlying type:_ _string_

Feature specifies which feature gate should be toggled

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

.Validation:
- Enum: [InstanceIdNodeName]

#### InstanceOptions

InstanceOptions determines how the node's operating system and devices are configured.

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `localStorage` _[LocalStorageOptions](#localstorageoptions)_ |  |

#### KubeletOptions

KubeletOptions are additional parameters passed to `kubelet`.

_Appears in:_
- [NodeConfigSpec](#nodeconfigspec)

| Field | Description |
| --- | --- |
| `config` _object (keys:string, values:[RawExtension](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#rawextension-runtime-pkg))_ | Config is a [`KubeletConfiguration`](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/)<br />that will be merged with the defaults. |
| `flags` _string array_ | Flags are [command-line `kubelet` arguments](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/).<br />that will be appended to the defaults. |

#### LocalStorageOptions

LocalStorageOptions control how [EC2 instance stores](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html)
are used when available.

_Appears in:_
- [InstanceOptions](#instanceoptions)

| Field | Description |
| --- | --- |
| `strategy` _[LocalStorageStrategy](#localstoragestrategy)_ |  |

#### LocalStorageStrategy

_Underlying type:_ _string_

LocalStorageStrategy specifies how to handle an instance's local storage devices.

_Appears in:_
- [LocalStorageOptions](#localstorageoptions)

.Validation:
- Enum: [RAID0 RAID10 Mount]

#### NodeConfig

NodeConfig is the primary configuration object for `nodeadm`.

| Field | Description |
| --- | --- |
| `apiVersion` _string_ | `node.eks.aws/v1alpha1`
| `kind` _string_ | `NodeConfig`
| `kind` _string_ | Kind is a string value representing the REST resource this object represents.<br />Servers may infer this from the endpoint the client submits requests to.<br />Cannot be updated.<br />In CamelCase.<br />More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds |
| `apiVersion` _string_ | APIVersion defines the versioned schema of this representation of an object.<br />Servers should convert recognized schemas to the latest internal value, and<br />may reject unrecognized values.<br />More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources |
| `metadata` _[ObjectMeta](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.29/#objectmeta-v1-meta)_ | Refer to Kubernetes API documentation for fields of `metadata`. |
| `spec` _[NodeConfigSpec](#nodeconfigspec)_ |  |

#### NodeConfigSpec

_Appears in:_
- [NodeConfig](#nodeconfig)

| Field | Description |
| --- | --- |
| `cluster` _[ClusterDetails](#clusterdetails)_ |  |
| `containerd` _[ContainerdOptions](#containerdoptions)_ |  |
| `instance` _[InstanceOptions](#instanceoptions)_ |  |
| `kubelet` _[KubeletOptions](#kubeletoptions)_ |  |
| `featureGates` _object (keys:[Feature](#feature), values:boolean)_ | FeatureGates holds key-value pairs to enable or disable application features. |
