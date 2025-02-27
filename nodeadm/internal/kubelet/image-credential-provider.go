package kubelet

import (
	"bytes"
	_ "embed"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"text/template"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
	"golang.org/x/mod/semver"
)

const (
	// #nosec G101 //constant path, not credential
	imageCredentialProviderRoot = "/etc/eks/image-credential-provider"
	// #nosec G101 //constant path, not credential
	imageCredentialProviderConfig = "config.json"
	imageCredentialProviderPerm   = 0644
	// #nosec G101 //constant path, not credential
	ecrCredentialProviderBinPathEnvironmentName = "ECR_CREDENTIAL_PROVIDER_BIN_PATH"
)

var (
	//go:embed image-credential-provider.json.tpl
	imageCredentialProviderTemplateData string
	imageCredentialProviderTemplate     = template.Must(template.New("image-credential-provider").Parse(imageCredentialProviderTemplateData))
	imageCredentialProviderConfigPath   = path.Join(imageCredentialProviderRoot, imageCredentialProviderConfig)

	matchImages = []string{"*.dkr.ecr.*.amazonaws.com",
		"*.dkr-ecr.*.on.aws",
		"*.dkr.ecr.*.amazonaws.com.cn",
		"*.dkr-ecr.*.on.amazonwebservices.com.cn",
		"*.dkr.ecr-fips.*.amazonaws.com",
		"*.dkr-ecr-fips.*.on.aws",
		"*.dkr.ecr.*.c2s.ic.gov",
		"*.dkr.ecr.*.sc2s.sgov.gov",
		"*.dkr.ecr.*.cloud.adc-e.uk",
		"*.dkr.ecr.*.csp.hci.ic.gov",
	}
)

func (k *kubelet) writeImageCredentialProviderConfig(cfg *api.NodeConfig) error {
	// fallback default for image credential provider binary if not overridden
	ecrCredentialProviderBinPath := path.Join(imageCredentialProviderRoot, "ecr-credential-provider")
	if binPath, set := os.LookupEnv(ecrCredentialProviderBinPathEnvironmentName); set {
		zap.L().Info("picked up image credential provider binary path from environment", zap.String("bin-path", binPath))
		ecrCredentialProviderBinPath = binPath
	}
	if err := ensureCredentialProviderBinaryExists(ecrCredentialProviderBinPath); err != nil {
		return err
	}

	config, err := generateImageCredentialProviderConfig(cfg, ecrCredentialProviderBinPath)
	if err != nil {
		return err
	}

	k.flags["image-credential-provider-bin-dir"] = path.Dir(ecrCredentialProviderBinPath)
	k.flags["image-credential-provider-config"] = imageCredentialProviderConfigPath

	return util.WriteFileWithDir(imageCredentialProviderConfigPath, config, imageCredentialProviderPerm)
}

type imageCredentialProviderTemplateVars struct {
	ConfigApiVersion   string
	ProviderApiVersion string
	EcrProviderName    string
	MatchImages        []string
}

func generateImageCredentialProviderConfig(cfg *api.NodeConfig, ecrCredentialProviderBinPath string) ([]byte, error) {
	templateVars := imageCredentialProviderTemplateVars{
		EcrProviderName: filepath.Base(ecrCredentialProviderBinPath),
		MatchImages:     matchImages,
	}
	kubeletVersion, err := GetKubeletVersion()
	if err != nil {
		return nil, err
	}
	if semver.Compare(kubeletVersion, "v1.27.0") < 0 {
		templateVars.ConfigApiVersion = "kubelet.config.k8s.io/v1alpha1"
		templateVars.ProviderApiVersion = "credentialprovider.kubelet.k8s.io/v1alpha1"
	} else {
		templateVars.ConfigApiVersion = "kubelet.config.k8s.io/v1"
		templateVars.ProviderApiVersion = "credentialprovider.kubelet.k8s.io/v1"
		// ecr-credential-provider has support for public.ecr.aws in 1.27+
		templateVars.MatchImages = append(templateVars.MatchImages, "public.ecr.aws")
	}
	var buf bytes.Buffer
	if err := imageCredentialProviderTemplate.Execute(&buf, templateVars); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

func ensureCredentialProviderBinaryExists(binPath string) error {
	if _, err := os.Stat(binPath); err != nil {
		return fmt.Errorf("image credential provider binary was not found on path %s. error: %s", binPath, err)
	}
	return nil
}
