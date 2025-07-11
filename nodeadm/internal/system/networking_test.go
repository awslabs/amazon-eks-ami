package system

import (
	_ "embed"
	"reflect"
	"testing"
)

//go:embed _assets/test_10-eks_primary_eni_only.conf
var testEKSPrimaryENIOnlyConfTemplateData []byte

func Test_generateEKSPrimaryENIOnlyConfiguration(t *testing.T) {
	type args struct {
		mac string
	}
	tests := []struct {
		name    string
		args    args
		want    []byte
		wantErr bool
	}{
		{
			name:    "mac is 0e:f7:72:74:2d:43",
			args:    args{mac: "0e:f7:72:74:2d:43"},
			want:    testEKSPrimaryENIOnlyConfTemplateData,
			wantErr: false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := generateEKSPrimaryENIOnlyConfiguration(tt.args.mac)
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
