package hybrid_test

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/hybrid"
)

func TestWriteAWSConfig(t *testing.T) {
	err := hybrid.WriteAWSConfig(hybrid.AWSConfig{})
	if err != nil {
		t.Fatal(err)
	}
}
