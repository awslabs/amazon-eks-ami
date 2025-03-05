package kubelet

import (
	"bytes"
	_ "embed"
	"fmt"
	"log"
	"os"
	"path"
	"path/filepath"
	"time"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"go.uber.org/zap"
	"golang.org/x/mod/semver"
	k8smetav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	k8sruntime "k8s.io/apimachinery/pkg/runtime"
	k8sjson "k8s.io/apimachinery/pkg/runtime/serializer/json"
	k8sconfigv1 "k8s.io/kubelet/config/v1"
	k8sconfigv1alpha1 "k8s.io/kubelet/config/v1alpha1"
	"sigs.k8s.io/controller-runtime/pkg/client/apiutil"
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

	config, err := generateImageCredentialProviderConfig(ecrCredentialProviderBinPath)
	if err != nil {
		return err
	}

	k.flags["image-credential-provider-bin-dir"] = path.Dir(ecrCredentialProviderBinPath)
	k.flags["image-credential-provider-config"] = imageCredentialProviderConfigPath

	return util.WriteFileWithDir(imageCredentialProviderConfigPath, config, imageCredentialProviderPerm)
}

func generateImageCredentialProviderConfig(ecrCredentialProviderBinPath string) ([]byte, error) {
	scheme := k8sruntime.NewScheme()
	providerName := filepath.Base(ecrCredentialProviderBinPath)
	defaultCacheDuration := &k8smetav1.Duration{Duration: 12 * time.Hour}
	matchImages := []string{
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
	}
	kubeletVersion, err := GetKubeletVersion()
	if err != nil {
		return nil, err
	}
	var cfg k8sruntime.Object
	if semver.Compare(kubeletVersion, "v1.27.0") < 0 {
		err = k8sconfigv1alpha1.AddToScheme(scheme)
		if err != nil {
			return nil, err
		}
		k8sconfigv1.AddToScheme(scheme)
		cfg = &k8sconfigv1alpha1.CredentialProviderConfig{
			Providers: []k8sconfigv1alpha1.CredentialProvider{
				{
					Name:                 providerName,
					MatchImages:          matchImages,
					DefaultCacheDuration: defaultCacheDuration,
					APIVersion:           "credentialprovider.kubelet.k8s.io/v1alpha1",
				},
			},
		}
	} else {
		err = k8sconfigv1.AddToScheme(scheme)
		if err != nil {
			return nil, err
		}
		cfg = &k8sconfigv1.CredentialProviderConfig{
			Providers: []k8sconfigv1.CredentialProvider{
				{
					Name:                 providerName,
					MatchImages:          append(matchImages, "public.ecr.aws"),
					DefaultCacheDuration: defaultCacheDuration,
					APIVersion:           "credentialprovider.kubelet.k8s.io/v1",
				},
			},
		}
	}
	gvk, err := apiutil.GVKForObject(cfg, scheme)
	if err != nil {
		log.Println(err)
	}
	cfg.GetObjectKind().SetGroupVersionKind(gvk)
	serializer := k8sjson.NewSerializerWithOptions(k8sjson.DefaultMetaFactory, scheme, scheme, k8sjson.SerializerOptions{Pretty: true})

	var buf bytes.Buffer
	err = serializer.Encode(cfg, &buf)
	if err != nil {
		log.Println(err)
	}
	return buf.Bytes(), nil
}

func ensureCredentialProviderBinaryExists(binPath string) error {
	if _, err := os.Stat(binPath); err != nil {
		return fmt.Errorf("image credential provider binary was not found on path %s. error: %s", binPath, err)
	}
	return nil
}
