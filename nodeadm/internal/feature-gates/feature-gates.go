package featuregates

type FeatureGate = string

const (
	// When this flag is enabled, use a describe-cluster call
	// to repopulate all config data for ClusterDetails
	DescribeClusterDetails = FeatureGate("describeClusterDetails")
	// When this flag is enabled, override the kubelet
	// config with reserved cgroup values on behalf of the user
	DefaultReservedResources = FeatureGate("defaultReservedResources")
)

func DefaultTrue(featureGate FeatureGate, featureGates map[FeatureGate]bool) bool {
	enabled, set := featureGates[featureGate]
	return !set || enabled
}

func DefaultFalse(featureGate FeatureGate, featureGates map[FeatureGate]bool) bool {
	enabled, set := featureGates[featureGate]
	return set && enabled
}
