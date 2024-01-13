package v1alpha1

import (
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
	Cluster      ClusterDetails  `json:"cluster,omitempty"`
	FeatureGates map[string]bool `json:"featureGates,omitempty"`
}

type ClusterDetails struct {
	// +kubebuilder:validation:Required
	Name string `json:"name,omitempty"`
	// +kubebuilder:validation:Required
	APIServerEndpoint string `json:"apiServerEndpoint,omitempty"`
	// +kubebuilder:validation:Required
	CertificateAuthority []byte `json:"certificateAuthority,omitempty"`
	// +kubebuilder:validation:Required
	CIDR          string `json:"cidr,omitempty"`
	EnableOutpost *bool  `json:"enableOutpost,omitempty"`
	ID            string `json:"id,omitempty"`
}
