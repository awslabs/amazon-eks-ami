package featuregates

type FeatureGate struct {
	Key      string
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

var InstanceIdNodeName = FeatureGate{
	Key:      "InstanceIdNodeName",
	Verifier: DefaultFalse,
}
