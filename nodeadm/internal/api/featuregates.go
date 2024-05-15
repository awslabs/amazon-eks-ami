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
}

func IsFeatureEnabled(feature Feature, featureGates map[Feature]bool) bool {
	if verifier, exists := featureVerifiers[feature]; exists {
		return verifier(feature, featureGates)
	}
	return false
}
