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
	Cluster      ClusterDetails    `json:"cluster,omitempty"`
	Containerd   ContainerdOptions `json:"containerd,omitempty"`
	Kubelet      KubeletOptions    `json:"kubelet,omitempty"`
	FeatureGates map[string]bool   `json:"featureGates,omitempty"`
}

type ClusterDetails struct {
	// +kubebuilder:validation:Required
	Name                 string   `json:"name,omitempty"`
	APIServerEndpoint    string   `json:"apiServerEndpoint,omitempty"`
	CertificateAuthority []byte   `json:"certificateAuthority,omitempty"`
	DNSAddress           string   `json:"dnsAddress,omitempty"`
	IPFamily             IPFamily `json:"ipFamily,omitempty"`
	CIDR                 string   `json:"cidr,omitempty"`
	EnableOutpost        *bool    `json:"enableOutpost,omitempty"`
	ID                   string   `json:"id,omitempty"`
}

// +kubebuilder:validation:Enum=ipv4;ipv6
type IPFamily string

const (
	IPFamilyIPv4 IPFamily = "ipv4"
	IPFamilyIPv6 IPFamily = "ipv6"
)

type DaemonConfigOptions struct {
	Source string `json:"source,omitempty"`
	Inline string `json:"inline,omitempty"`
	// +kubebuilder:default=false
	MergeWithDefaults bool `json:"mergeWithDefaults,omitempty"`
}

type ContainerdOptions struct {
	Config DaemonConfigOptions `json:"config,omitempty"`
}

type KubeletOptions struct {
	// +kubebuilder:default={}
	AdditionalArguments map[string]string   `json:"additionalArguments,omitempty"`
	Config              DaemonConfigOptions `json:"config,omitempty"`
}

// +kubebuilder:validation:Enum=debug;info;warn;error
type LogLevel string

const (
	LogLevelDebug LogLevel = "debug"
	LogLevelInfo  LogLevel = "info"
	LogLevelWarn  LogLevel = "warn"
	LogLevelError LogLevel = "error"
)

type ContainerCoordinates struct {
	Ref string `json:"ref,omitempty"`
}
