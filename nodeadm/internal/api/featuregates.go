package api

func DefaultTrue(key Feature, featureGates map[Feature]bool) bool {
	enabled, set := featureGates[key]
	return !set || enabled
}

func DefaultFalse(key Feature, featureGates map[Feature]bool) bool {
	enabled, set := featureGates[key]
	return set && enabled
}

var featureVerifiers = map[Feature]func(Feature, map[Feature]bool) bool{
	// InstanceIdNodeNameGate controls whether to use instance ID as the node's name.
	// By default, this feature is disabled, and the private DNS Name will be used.
	InstanceIdNodeName: DefaultFalse,

	// FastImagePull enables a parallel image pull for container images. This
	// will use more instance CPU, Memory, and EBS I/O during image pull, but
	// may result in faster image pull times. This flag will be ignored on
	// instances with memory and vCPU below a certain threshold.
	FastImagePull: DefaultFalse,

	// OSManagedNoManageENIs configures secondary ENIs tagged
	// node.k8s.amazonaws.com/no_manage=true via systemd-networkd instead of
	// leaving them to the VPC CNI, which ignores them. Requires
	// ec2:DescribeNetworkInterfaces on the node instance role.
	OSManagedNoManageENIs: DefaultFalse,
}

func IsFeatureEnabled(feature Feature, featureGates map[Feature]bool) bool {
	if verifier, exists := featureVerifiers[feature]; exists {
		return verifier(feature, featureGates)
	}
	return false
}

// UseInstanceIdNodeName reports whether the node should be named after its EC2
// instance ID rather than its private DNS name. It is the single source of
// truth for that decision, used both when enriching status (to skip the EC2
// private-DNS-name lookup) and when setting kubelet's hostname-override.
//
// Enabled when the InstanceIdNodeName gate is explicitly on (any OS), or when
// the host is AL2027 and the user has not set the gate. AL2027 defaults to
// instance-id naming because the private-DNS-name scheme depends on resolver
// behavior AL2027 no longer provides by default. An explicit user setting always
// wins, including turning it off on AL2027.
func UseInstanceIdNodeName(featureGates map[Feature]bool, osDistro OSDistro) bool {
	if enabled, set := featureGates[InstanceIdNodeName]; set {
		return enabled
	}
	return osDistro == OSDistroAL2027
}
