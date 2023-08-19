package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type BootstrapConfig struct {
	metav1.TypeMeta `json:",inline"`

	Spec BootstrapConfigSpec `json:"spec"`
}

// BootstrapConfigSpec is the top-level type for configuring the bootstrap process of an EKS node
type BootstrapConfigSpec struct {
	ClusterDetails ClusterDetails `json:"clusterDetails"`
}

// ClusterDetails is the details of an EKS cluster
type ClusterDetails struct {
	Name                 string `json:"name"`
	APIServerEndpoint    string `json:"apiServerEndpoint"`
	CertificateAuthority string `json:"certificateAuthority"`
}
