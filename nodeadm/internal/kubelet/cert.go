package kubelet

import (
	"os"
	"path"
)

const caCertificatePath = "/etc/kubernetes/pki/ca.crt"

// Write the cluster certifcate authority to the filesystem where
// both kubelet and kubeconfig can read it
func writeClusterCaCert(caCert []byte) error {
	if err := os.MkdirAll(path.Dir(caCertificatePath), kubeletConfigPerm); err != nil {
		return err
	}
	return os.WriteFile(caCertificatePath, caCert, kubeletConfigPerm)
}
