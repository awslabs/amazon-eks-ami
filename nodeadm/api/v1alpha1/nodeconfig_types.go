package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

func init() {
	SchemeBuilder.Register(&NodeConfig{}, &NodeConfigList{})
}

// +kubebuilder:object:root=true
// +kubebuilder:resource:scope=Cluster
// +kubebuilder:storageversion

// NodeConfig is the primary configuration object for `nodeadm`.
type NodeConfig struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              NodeConfigSpec `json:"spec,omitempty"`
}

// +kubebuilder:object:root=true

// NodeConfigList contains a list of NodeConfig
type NodeConfigList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []NodeConfig `json:"items"`
}

type NodeConfigSpec struct {
	Cluster    ClusterDetails    `json:"cluster,omitempty"`
	Kubelet    KubeletOptions    `json:"kubelet,omitempty"`
	Containerd ContainerdOptions `json:"containerd,omitempty"`
}

// ClusterDetails contains the coordinates of your EKS cluster.
// These details can be found using the [DescribeCluster API](https://docs.aws.amazon.com/eks/latest/APIReference/API_DescribeCluster.html).
type ClusterDetails struct {
	// Name is the name of your EKS cluster
	Name string `json:"name,omitempty"`

	// APIServerEndpoint is the URL of your EKS cluster's kube-apiserver.
	APIServerEndpoint string `json:"apiServerEndpoint,omitempty"`

	// CertificateAuthority is a base64-encoded string of your cluster's certificate authority chain.
	CertificateAuthority []byte `json:"certificateAuthority,omitempty"`

	// CIDR is your cluster's Pod IP CIDR. This value is used to infer your cluster's DNS address.
	CIDR string `json:"cidr,omitempty"`

	// EnableOutpost determines how your node is configured when running on an AWS Outpost.
	EnableOutpost *bool `json:"enableOutpost,omitempty"`

	// ID is an identifier for your cluster; this is only used when your node is running on an AWS Outpost.
	ID string `json:"id,omitempty"`
}

type KubeletOptions struct {
	// Config is a kubelet config that can be provided by the user to override
	// default generated configurations
	// https://kubernetes.io/docs/reference/config-api/kubelet-config.v1/
	Config map[string]runtime.RawExtension `json:"config,omitempty"`

	// Flags is a list of command-line kubelet arguments. These arguments are
	// amended to the generated defaults, and therefore will act as overrides
	// https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
	Flags []string `json:"flags,omitempty"`
}

type ContainerdOptions struct {
	// Config is an inline containerd config toml document that can be provided
	// by the user to override default generated configurations
	// https://github.com/containerd/containerd/blob/main/docs/man/containerd-config.toml.5.md
	Config string `json:"config,omitempty"`
}
