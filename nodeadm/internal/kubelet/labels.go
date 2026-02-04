package kubelet

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/system"
)

type LabelProvider interface {
	Get() (string, bool, error)
}

type NvidiaGPULabel struct {
	fs system.FileSystem
}

func (n NvidiaGPULabel) Get() (string, bool, error) {
	ok, err := system.IsPCIVendorAttached(n.fs, system.NVIDIA_VENDOR_ID)
	if err != nil {
		return "", false, err
	}
	if !ok {
		return "", false, nil
	}
	return "true", true, nil
}
