package system

import (
	_ "embed"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"reflect"
	"testing"
)

//go:embed _assets/test_10-eks_primary_eni_only.conf
var testEKSPrimaryENIOnlyConfTemplateData []byte

func Test_networkingAspect_generateEKSPrimaryENIOnlyConfiguration(t *testing.T) {
	type args struct {
		cfg *api.NodeConfig
	}
	tests := []struct {
		name    string
		args    args
		want    []byte
		wantErr bool
	}{
		{
			name: "mac is 0e:f7:72:74:2d:43",
			args: args{
				cfg: &api.NodeConfig{
					Status: api.NodeConfigStatus{
						Instance: api.InstanceDetails{
							MAC: "0e:f7:72:74:2d:43",
						},
					},
				},
			},
			want:    testEKSPrimaryENIOnlyConfTemplateData,
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			a := &networkingAspect{}
			got, err := a.generateEKSPrimaryENIOnlyConfiguration(tt.args.cfg)
			if (err != nil) != tt.wantErr {
				t.Errorf("generateEKSPrimaryENIOnlyConfiguration() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("generateEKSPrimaryENIOnlyConfiguration() got = %v, want %v", got, tt.want)
			}
		})
	}
}
