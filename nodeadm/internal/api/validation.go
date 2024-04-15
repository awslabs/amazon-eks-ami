package api

import "fmt"

func ValidateNodeConfig(cfg *NodeConfig) error {
	if enabled := cfg.Spec.Cluster.EnableOutpost; enabled != nil && *enabled {
		if cfg.Spec.Cluster.ID == "" {
			return fmt.Errorf("cidr is missing in cluster configuration")
		}
	}
	return nil
}
