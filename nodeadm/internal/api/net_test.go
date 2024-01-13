package api

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestClusterDNS(t *testing.T) {
	var tests = []struct {
		clusterCIDR        string
		expectedClusterDns string
	}{
		{
			clusterCIDR:        "10.100.0.0/16",
			expectedClusterDns: "10.100.0.10",
		},
	}

	for _, test := range tests {
		details := ClusterDetails{
			CIDR: test.clusterCIDR,
		}
		clusterDns, err := details.GetClusterDns()
		if err != nil {
			t.Error(err)
		}
		assert.Equal(t, test.expectedClusterDns, clusterDns)
	}
}
