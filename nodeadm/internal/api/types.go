// +kubebuilder:object:generate=true
// +groupName=node.eks.aws
package api

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +kubebuilder:skipversion
// +kubebuilder:object:root=true

type NodeConfig struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`
	Spec              NodeConfigSpec `json:"spec,omitempty"`
	// +k8s:conversion-gen=false
	Status NodeConfigStatus `json:"status,omitempty"`
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

type NodeConfigStatus struct {
	Instance InstanceDetails `json:"instance,omitempty"`
}

type InstanceDetails struct {
	ID               string `json:"id,omitempty"`
	Region           string `json:"region,omitempty"`
	Type             string `json:"type,omitempty"`
	AvailabilityZone string `json:"availabilityZone,omitempty"`
	MAC              string `json:"mac,omitempty"`
}

type ClusterDetails struct {
	Name                 string   `json:"name,omitempty"`
	APIServerEndpoint    string   `json:"apiServerEndpoint,omitempty"`
	CertificateAuthority []byte   `json:"certificateAuthority,omitempty"`
	DNSAddress           string   `json:"dnsAddress,omitempty"`
	IPFamily             IPFamily `json:"ipFamily,omitempty"`
	CIDR                 string   `json:"cidr,omitempty"`
	EnableOutpost        *bool    `json:"enableOutpost,omitempty"`
	ID                   string   `json:"id,omitempty"`
}

type IPFamily string

const (
	IPFamilyIPv4 IPFamily = "ipv4"
	IPFamilyIPv6 IPFamily = "ipv6"
)

type DaemonConfigOptions struct {
	Source            string `json:"source,omitempty"`
	Inline            string `json:"inline,omitempty"`
	MergeWithDefaults bool   `json:"mergeWithDefaults,omitempty"`
}

type ContainerdOptions struct {
	Config DaemonConfigOptions `json:"config,omitempty"`
}

type KubeletOptions struct {
	AdditionalArguments map[string]string   `json:"additionalArguments,omitempty"`
	Config              DaemonConfigOptions `json:"config,omitempty"`
}

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
