package util

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
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
		clusterDns, err := GetClusterDns(&api.ClusterDetails{
			CIDR: test.clusterCIDR,
		},
		)
		if err != nil {
			t.Error(err)
		}
		assert.Equal(t, test.expectedClusterDns, clusterDns)
	}
}
