package v1alpha1

import (
	v1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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
	Cluster ClusterDetails `json:"cluster,omitempty"`
	Kubelet KubeletOptions `json:"kubelet,omitempty"`
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
	// InlineConfig is a raw document of a kubelet config that can be provided
	// by the user to override default generated configurations
	InlineConfig string `json:"inline,omitempty"`
	// Flags is a string map that takes command-line kubelet arguments without
	// leading dashes. These arguments override any of generated defaults
	// https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
	Flags map[string]string `json:"flags,omitempty"`
	// Labels is a map of labels to apply to the node when the kubelet
	// registers itself
	Labels map[string]string `json:"labels,omitempty"`
	// Labels is a map of labels to apply to the node when the kubelet
	// registers itself
	Taints []v1.Taint `json:"taints,omitempty"`
}
