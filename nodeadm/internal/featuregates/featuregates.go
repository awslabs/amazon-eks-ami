package featuregates

type FeatureGate struct {
	// Key of the feature
	Key string
	// Verifier that will validate input and set default value
	Verifier func(string, map[string]bool) bool
}

func DefaultTrue(key string, featureGates map[string]bool) bool {
	enabled, set := featureGates[key]
	return !set || enabled
}

func DefaultFalse(key string, featureGates map[string]bool) bool {
	enabled, set := featureGates[key]
	return set && enabled
}

func (fg FeatureGate) IsEnabled(featureGates map[string]bool) bool {
	return fg.Verifier(fg.Key, featureGates)
}

// InstanceIdNodeName controls whether to use instance ID as node name for AL2023 node group.
// By default, this feature is disabled, and the private DNS Name will be used.
var InstanceIdNodeName = FeatureGate{
	Key:      "InstanceIdNodeName",
	Verifier: DefaultFalse,
}
