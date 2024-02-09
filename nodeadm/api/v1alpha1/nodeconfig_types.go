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

// NodeConfig is the Schema for the nodeconfigs API
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

type ClusterDetails struct {
	Name                 string `json:"name,omitempty"`
	APIServerEndpoint    string `json:"apiServerEndpoint,omitempty"`
	CertificateAuthority []byte `json:"certificateAuthority,omitempty"`
	CIDR                 string `json:"cidr,omitempty"`
	EnableOutpost        *bool  `json:"enableOutpost,omitempty"`
	ID                   string `json:"id,omitempty"`
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
