package containerd

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

func TestGenerateConfig(t *testing.T) {
	cfg := api.NodeConfig{
		Status: api.NodeConfigStatus{
			Instance: api.InstanceDetails{
				Region: "us-west-2",
			},
		},
	}
	if _, err := generateContainerdConfig(&cfg); err != nil {
		t.Error(err)
	}
}
