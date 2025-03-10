package ipamd

import (
	"net"
	"time"
)

// These types are copied from github.com/aws/amazon-vpc-cni-k8s/pkg/ipamd/datastore
// This is done because the dependency graph for that package is too large.
// TODO: add a proper dependency on a dedicated API type pkg

// ENIInfos contains ENI IP information
type ENIInfos struct {
	// TotalIPs is the total number of IP addresses
	TotalIPs int
	// assigned is the number of IP addresses that has been assigned
	AssignedIPs int
	// ENIs contains ENI IP pool information
	ENIs map[string]ENI
}

// ENI represents a single ENI. Exported fields will be marshaled for introspection.
type ENI struct {
	// AWS ENI ID
	ID         string
	createTime time.Time
	// IsPrimary indicates whether ENI is a primary ENI
	IsPrimary bool
	// IsTrunk indicates whether this ENI is used to provide pods with dedicated ENIs
	IsTrunk bool
	// IsEFA indicates whether this ENI is tagged as an EFA
	IsEFA bool
	// DeviceNumber is the device number of ENI (0 means the primary ENI)
	DeviceNumber int
	// IPv4Addresses shows whether each address is assigned, the key is IP address, which must
	// be in dot-decimal notation with no leading zeros and no whitespace(eg: "10.1.0.253")
	// Key is the IP address - PD: "IP/28" and SIP: "IP/32"
	AvailableIPv4Cidrs map[string]*CidrInfo
	//IPv6CIDRs contains information tied to IPv6 Prefixes attached to the ENI
	IPv6Cidrs map[string]*CidrInfo
}

// CidrInfo
type CidrInfo struct {
	// Either v4/v6 Host or LPM Prefix
	Cidr net.IPNet
	// Key is individual IP addresses from the Prefix - /32 (v4) or /128 (v6)
	IPAddresses map[string]*AddressInfo
	// true if Cidr here is an LPM prefix
	IsPrefix bool
	// IP Address Family of the Cidr
	AddressFamily string
}

// AddressInfo contains information about an IP, Exported fields will be marshaled for introspection.
type AddressInfo struct {
	Address string

	IPAMKey        IPAMKey
	IPAMMetadata   IPAMMetadata
	AssignedTime   time.Time
	UnassignedTime time.Time
}

// IPAMKey is the IPAM primary key.  Quoting CNI spec:
//
//	Plugins that store state should do so using a primary key of
//	(network name, CNI_CONTAINERID, CNI_IFNAME).
type IPAMKey struct {
	NetworkName string `json:"networkName"`
	ContainerID string `json:"containerID"`
	IfName      string `json:"ifName"`
}

// IPAMMetadata is the metadata associated with IP allocations.
type IPAMMetadata struct {
	K8SPodNamespace string `json:"k8sPodNamespace,omitempty"`
	K8SPodName      string `json:"k8sPodName,omitempty"`
}
