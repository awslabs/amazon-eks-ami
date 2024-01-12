package kubelet

import (
	"bytes"
	_ "embed"
	"os"
	"path"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

const (
	kubeconfigRoot          = "/var/lib/kubelet"
	kubeconfigFile          = "kubeconfig"
	kubeconfigBootstrapFile = "bootstrap-kubeconfig"
	kubeconfigPerm          = 0644
)

var (
	//go:embed kubeconfig.template.yaml
	kubeconfigTemplateData  string
	kubeconfigTemplate      = template.Must(template.New(kubeconfigFile).Parse(kubeconfigTemplateData))
	kubeconfigPath          = path.Join(kubeconfigRoot, kubeconfigFile)
	kubeconfigBootstrapPath = path.Join(kubeconfigRoot, kubeconfigBootstrapFile)
)

func (k *kubelet) writeKubeconfig(cfg *api.NodeConfig) error {
	if enabled := cfg.Spec.Cluster.EnableOutpost; enabled != nil && *enabled {
		kubeconfig, err := generateKubeconfig(cfg, true)
		if err != nil {
			return err
		}
		// kubelet bootstrap kubeconfig uses aws-iam-authenticator with cluster id to authenticate to cluster
		//   - if "aws eks describe-cluster" is bypassed, for local outpost, the value of CLUSTER_NAME parameter will be cluster id.
		//   - otherwise, the cluster id will use the id returned by "aws eks describe-cluster".
		cfg.Spec.Kubelet.AdditionalArguments["bootstrap-kubeconfig"] = kubeconfigBootstrapPath
		return writeConfig(kubeconfigBootstrapPath, kubeconfig)
	} else {
		kubeconfig, err := generateKubeconfig(cfg, false)
		if err != nil {
			return err
		}
		cfg.Spec.Kubelet.AdditionalArguments["kubeconfig"] = kubeconfigPath
		return writeConfig(kubeconfigPath, kubeconfig)
	}
}

type kubeconfig struct {
	Cluster           string
	Region            string
	APIServerEndpoint string
	CaCertPath        string
}

func generateKubeconfig(cfg *api.NodeConfig, isOutpost bool) ([]byte, error) {
	cluster := cfg.Spec.Cluster.Name
	if isOutpost {
		cluster = cfg.Spec.Cluster.ID
	}

	config := kubeconfig{
		Cluster:           cluster,
		Region:            cfg.Status.Instance.Region,
		APIServerEndpoint: cfg.Spec.Cluster.APIServerEndpoint,
		CaCertPath:        caCertificatePath,
	}

	var buf bytes.Buffer
	if err := kubeconfigTemplate.Execute(&buf, config); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func writeConfig(path string, data []byte) error {
	if err := os.MkdirAll(kubeconfigRoot, kubeconfigPerm); err != nil {
		return err
	}
	return os.WriteFile(path, data, kubeconfigPerm)
}
