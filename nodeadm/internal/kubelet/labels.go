package kubelet

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

type LabelValueFunc func() (string, bool, error)

func getNvidiaGPULabel() (string, bool, error) {
	ok, err := util.IsPCIVendorAttached(util.NVIDIA_VENDOR_ID)
	if err != nil {
		return "", false, err
	}
	if !ok {
		return "", false, nil
	}
	return "true", true, nil
}
