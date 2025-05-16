package system

import (
	_ "embed"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/stretchr/testify/assert"
)

func Test_networkingAspect_generateEKSPrimaryENIOnlyConfiguration(t *testing.T) {
	testCases := []struct {
		name    string
		cfg     api.NodeConfig
		want    []byte
		wantErr bool
	}{
		{
			name: "mac is 0e:f7:72:74:2d:43",
			cfg: api.NodeConfig{
				Status: api.NodeConfigStatus{
					Instance: api.InstanceDetails{
						MAC: "0e:f7:72:74:2d:43",
					},
				},
			},
			want: []byte(`[Match]
PermanentMACAddress=0e:f7:72:74:2d:43

[DHCPv4]
RouteMetric=512

[IPv6AcceptRA]
RouteMetric=512
UseGateway=true`),
		},
	}
	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			got, err := generatePrimaryInterfaceNetworkConfiguration(&testCase.cfg)
			assert.Equal(t, testCase.wantErr, err != nil, "error does not match wantErr=%v", testCase.wantErr)
			assert.Equal(t, testCase.want, got)
		})
	}
}
