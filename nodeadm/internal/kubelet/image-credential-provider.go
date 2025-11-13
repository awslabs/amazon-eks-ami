package kubelet

import (
	"bytes"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"

	k8sjson "k8s.io/apimachinery/pkg/runtime/serializer/json"
	"k8s.io/apimachinery/pkg/runtime/serializer/versioning"
	configv1 "k8s.io/kubelet/config/v1"
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

var imageCredentialProviderConfigPath = path.Join(imageCredentialProviderRoot, imageCredentialProviderConfig)

func (k *kubelet) writeImageCredentialProviderConfig() error {
	// fallback default for image credential provider binary if not overridden
	ecrCredentialProviderBinPath := path.Join(imageCredentialProviderRoot, "ecr-credential-provider")
	if binPath, set := os.LookupEnv(ecrCredentialProviderBinPathEnvironmentName); set {
		zap.L().Info("picked up image credential provider binary path from environment", zap.String("bin-path", binPath))
		ecrCredentialProviderBinPath = binPath
	}
	if err := ensureCredentialProviderBinaryExists(ecrCredentialProviderBinPath); err != nil {
		return err
	}

	config, err := generateImageCredentialProviderConfig(ecrCredentialProviderBinPath)
	if err != nil {
		return err
	}

	k.flags["image-credential-provider-bin-dir"] = path.Dir(ecrCredentialProviderBinPath)
	k.flags["image-credential-provider-config"] = imageCredentialProviderConfigPath

	return util.WriteFileWithDir(imageCredentialProviderConfigPath, config, imageCredentialProviderPerm)
}

func generateImageCredentialProviderConfig(ecrCredentialProviderBinPath string) ([]byte, error) {
	cfg := configv1.CredentialProviderConfig{
		Providers: []configv1.CredentialProvider{
			{
				Name: filepath.Base(ecrCredentialProviderBinPath),
				MatchImages: []string{
					"*.dkr.ecr.*.amazonaws.com",
					"*.dkr-ecr.*.on.aws",
					"*.dkr.ecr.*.amazonaws.com.cn",
					"*.dkr-ecr.*.on.amazonwebservices.com.cn",
					"*.dkr.ecr-fips.*.amazonaws.com",
					"*.dkr-ecr-fips.*.on.aws",
					"*.dkr.ecr.*.c2s.ic.gov",
					"*.dkr.ecr.*.sc2s.sgov.gov",
					"*.dkr.ecr.*.cloud.adc-e.uk",
					"*.dkr.ecr.*.csp.hci.ic.gov",
					"*.dkr.ecr.*.amazonaws.eu",
					"public.ecr.aws",
				},
				APIVersion:           "credentialprovider.kubelet.k8s.io/v1",
				DefaultCacheDuration: &metav1.Duration{Duration: 12 * time.Hour},
			},
		},
	}
	var scheme = runtime.NewScheme()
	if err := configv1.AddToScheme(scheme); err != nil {
		return nil, err
	}
	serializer := k8sjson.NewSerializerWithOptions(k8sjson.DefaultMetaFactory, scheme, scheme, k8sjson.SerializerOptions{Pretty: true})
	var buf bytes.Buffer
	if err := versioning.NewDefaultingCodecForScheme(scheme, serializer, nil, nil, nil).Encode(&cfg, &buf); err != nil {
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
