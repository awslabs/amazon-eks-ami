package kubelet

import (
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path"
	"strings"
	"time"

	"go.uber.org/zap"
	"golang.org/x/mod/semver"

	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	logsapi "k8s.io/component-base/logs/api/v1"
	k8skubelet "k8s.io/kubelet/config/v1beta1"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/aws/smithy-go/ptr"

	"github.com/awslabs/amazon-eks-ami/nodeadm/api/v1alpha1"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	featuregates "github.com/awslabs/amazon-eks-ami/nodeadm/internal/feature-gates"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
)

const (
	kubeletConfigRoot = "/etc/kubernetes/kubelet"
	kubeletConfigFile = "config.json"
	kubeletConfigDir  = "config.json.d"
	kubeletConfigPerm = 0644
)

// kubeletSubConfig is an internal-only representation of the kubelet
// configuration that will be get written to disk. It is a subset of the
// upstream KubeletConfiguration types, and inherits the subset of parameters
// passed through NodeConfig KubeletConfiguration.
// https://pkg.go.dev/k8s.io/kubelet/config/v1beta1#KubeletConfiguration
type kubeletSubConfig struct {
	v1.TypeMeta                   `json:",inline"`
	v1alpha1.KubeletConfiguration `json:",inline"`
	Address                       string                           `json:"address"`
	Authentication                k8skubelet.KubeletAuthentication `json:"authentication"`
	Authorization                 k8skubelet.KubeletAuthorization  `json:"authorization"`
	CgroupDriver                  string                           `json:"cgroupDriver"`
	CgroupRoot                    string                           `json:"cgroupRoot"`
	ClusterDomain                 string                           `json:"clusterDomain"`
	ContainerRuntimeEndpoint      string                           `json:"containerRuntimeEndpoint"`
	FeatureGates                  map[string]bool                  `json:"featureGates"`
	HairpinMode                   string                           `json:"hairpinMode"`
	ProtectKernelDefaults         bool                             `json:"protectKernelDefaults"`
	ReadOnlyPort                  int                              `json:"readOnlyPort"`
	Logging                       logsapi.LoggingConfiguration     `json:"logging"`
	SerializeImagePulls           bool                             `json:"serializeImagePulls"`
	ServerTLSBootstrap            bool                             `json:"serverTLSBootstrap"`
	TLSCipherSuites               []string                         `json:"tlsCipherSuites"`
	SystemReservedCgroup          *string                          `json:"systemReservedCgroup,omitempty"`
	KubeReservedCgroup            *string                          `json:"kubeReservedCgroup,omitempty"`
	ProviderID                    *string                          `json:"providerID,omitempty"`
	KubeAPIQPS                    *int                             `json:"kubeAPIQPS,omitempty"`
	KubeAPIBurst                  *int                             `json:"kubeAPIBurst,omitempty"`
}

func (k *kubelet) writeKubeletConfig(cfg *api.NodeConfig) error {
	kubeletConfig, err := k.GenerateKubeletConfig(cfg)
	if err != nil {
		return err
	}
	kubeletConfigData, err := json.MarshalIndent(kubeletConfig, "", strings.Repeat(" ", 4))
	if err != nil {
		return err
	}
	if err := os.MkdirAll(kubeletConfigRoot, kubeletConfigPerm); err != nil {
		return err
	}

	kubeletVersion, err := GetKubeletVersion()
	if err != nil {
		return err
	}
	if semver.Compare(kubeletVersion, "v1.28.0") < 0 {
		return k.writeKubeletConfigToFile(kubeletConfigData)
	} else {
		return k.writeKubeletConfigToDir(kubeletConfigData)
	}
}

// Creates an internal kubelet configuration from the public facing bootstrap
// kubelet configuration with additional sane defaults.
func defaultKubeletSubConfig(kubeletConfifuration *v1alpha1.KubeletConfiguration) kubeletSubConfig {
	return kubeletSubConfig{
		TypeMeta: v1.TypeMeta{
			Kind:       "KubeletConfiguration",
			APIVersion: "kubelet.config.k8s.io/v1beta1",
		},
		KubeletConfiguration: *kubeletConfifuration,
		Address:              "0.0.0.0",
		Authentication: k8skubelet.KubeletAuthentication{
			Anonymous: k8skubelet.KubeletAnonymousAuthentication{
				Enabled: ptr.Bool(false),
			},
			Webhook: k8skubelet.KubeletWebhookAuthentication{
				Enabled:  ptr.Bool(true),
				CacheTTL: v1.Duration{Duration: time.Minute * 2},
			},
			X509: k8skubelet.KubeletX509Authentication{
				ClientCAFile: caCertificatePath,
			},
		},
		Authorization: k8skubelet.KubeletAuthorization{
			Mode: "Webhook",
			Webhook: k8skubelet.KubeletWebhookAuthorization{
				CacheAuthorizedTTL:   v1.Duration{Duration: time.Minute * 5},
				CacheUnauthorizedTTL: v1.Duration{Duration: time.Second * 30},
			},
		},
		CgroupDriver:             "systemd",
		CgroupRoot:               "/",
		ClusterDomain:            "cluster.local",
		ContainerRuntimeEndpoint: "unix:///run/containerd/containerd.sock",
		FeatureGates: map[string]bool{
			"RotateKubeletServerCertificate": true,
		},
		HairpinMode:           "hairpin-veth",
		ProtectKernelDefaults: true,
		ReadOnlyPort:          0,
		Logging: logsapi.LoggingConfiguration{
			Verbosity: 2,
		},
		SerializeImagePulls: false,
		ServerTLSBootstrap:  true,
		TLSCipherSuites: []string{
			"TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
			"TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
			"TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
			"TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
			"TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
			"TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
			"TLS_RSA_WITH_AES_128_GCM_SHA256",
			"TLS_RSA_WITH_AES_256_GCM_SHA384",
		},
	}
}

// Update the ClusterDNS of the internal kubelet config using a heuristic based
// on the cluster service IP CIDR address.
func (ksc *kubeletSubConfig) withFallbackClusterDns(cluster *v1alpha1.ClusterDetails) error {
	clusterDns, err := api.GetClusterDns(cluster)
	if err != nil {
		return err
	}
	ksc.ClusterDNS = []string{clusterDns}
	return nil
}

// To support worker nodes to continue to communicate and connect to local cluster even when the Outpost
// is disconnected from the parent AWS Region, the following specific setup are required:
//   - append entries to /etc/hosts with the mappings of control plane host IP address and API server
//     domain name. So that the domain name can be resolved to IP addresses locally.
//   - use aws-iam-authenticator as bootstrap auth for kubelet TLS bootstrapping which downloads client
//     X.509 certificate and generate kubelet kubeconfig file which uses the client cert. So that the
//     worker node can be authentiacated through X.509 certificate which works for both connected and
//     disconnected state.
func (ksc *kubeletSubConfig) withOutpostSetup(cfg *api.NodeConfig) error {
	if enabled := cfg.Spec.Cluster.EnableOutpost; enabled != nil && *enabled {
		zap.L().Info("Setting up outpost..")

		if cfg.Spec.Cluster.ID == "" {
			return fmt.Errorf("clusterId cannot be empty when outpost is enabled.")
		}
		apiUrl, err := url.Parse(cfg.Spec.Cluster.APIServerEndpoint)
		if err != nil {
			return err
		}

		// TODO: cleanup
		output, err := exec.Command("getent", "hosts", apiUrl.Host).Output()
		if err != nil {
			return err
		}

		// append to /etc/hosts file with shuffled mappings of "IP address to API server domain name"
		f, err := os.OpenFile("/etc/hosts", os.O_APPEND|os.O_WRONLY, kubeletConfigPerm)
		if err != nil {
			return err
		}
		defer f.Close()
		if _, err := f.Write(output); err != nil {
			return err
		}
	}
	return nil
}

func (ksc *kubeletSubConfig) withNodeIp(cfg *api.NodeConfig, kubeletArguments map[string]string) error {
	nodeIp, err := getNodeIp(context.TODO(), imds.New(imds.Options{}), cfg)
	if err != nil {
		return err
	}
	kubeletArguments["node-ip"] = nodeIp
	zap.L().Info("Setup IP for node", zap.String("ip", nodeIp))
	return nil
}

func (ksc *kubeletSubConfig) withVersionToggles(kubeletVersion string, kubeletArguments map[string]string) {
	// TODO: remove when 1.26 is EOL
	if semver.Compare(kubeletVersion, "v1.27.0") < 0 {
		// --container-runtime flag is gone in 1.27+
		kubeletArguments["container-runtime"] = "remote"
		// --container-runtime-endpoint moved to kubelet config start from 1.27
		// https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.27.md?plain=1#L1800-L1801
		kubeletArguments["container-runtime-endpoint"] = ksc.ContainerRuntimeEndpoint
	}

	// TODO: Remove this during 1.27 EOL
	// Enable Feature Gate for KubeletCredentialProviders in versions less than 1.28 since this feature flag was removed in 1.28.
	if semver.Compare(kubeletVersion, "v1.28.0") < 0 {
		ksc.FeatureGates["KubeletCredentialProviders"] = true
	}

	// for K8s versions that suport API Priority & Fairness, increase our API server QPS
	// in 1.27, the default is already increased to 50/100, so use the higher defaults
	if semver.Compare(kubeletVersion, "v1.22.0") >= 0 && semver.Compare(kubeletVersion, "v1.27.0") < 0 {
		ksc.KubeAPIQPS = ptr.Int(10)
		ksc.KubeAPIBurst = ptr.Int(20)
	}
}

func (ksc *kubeletSubConfig) withCloudProvider(cfg *api.NodeConfig, kubeletArguments map[string]string) {
	// ref: https://github.com/kubernetes/kubernetes/pull/121367
	kubeletArguments["cloud-provider"] = "external"

	// provider ID needs to be specified when the cloud provider is
	// external. evaluate if this can be done within the cloud controller.
	// since the values are coming from IMDS this might not be feasible
	ksc.ProviderID = ptr.String(getProviderId(cfg.Status.Instance.AvailabilityZone, cfg.Status.Instance.ID))

	// use ec2 instance-id as node hostname which is unique, stable, and incurs
	// no additional requests
	kubeletArguments["hostname-override"] = cfg.Status.Instance.ID
}

// When the DefaultReservedResources flag is enabled, override the kubelet
// config with reserved cgroup values on behalf of the user
func (ksc *kubeletSubConfig) withDefaultReservedResources() {
	ksc.SystemReservedCgroup = ptr.String("/system")
	ksc.KubeReservedCgroup = ptr.String("/runtime")
}

func (k *kubelet) GenerateKubeletConfig(cfg *api.NodeConfig) (*kubeletSubConfig, error) {
	// Get the kubelet/kubernetes version to help conditionally enable features
	kubeletVersion, err := GetKubeletVersion()
	if err != nil {
		return nil, err
	}
	zap.L().Info("Detected kubelet version", zap.String("version", kubeletVersion))

	kubeletConfig := defaultKubeletSubConfig(&cfg.Spec.Kubelet.Config)

	// If ClusterDNS is not provided in the KubeletConfiguration, generate a
	// default value using the cluster service IP CIDR address.
	if len(kubeletConfig.ClusterDNS) == 0 {
		if err := kubeletConfig.withFallbackClusterDns(&cfg.Spec.Cluster); err != nil {
			return nil, err
		}
	}
	if err := kubeletConfig.withOutpostSetup(cfg); err != nil {
		return nil, err
	}
	if err := kubeletConfig.withNodeIp(cfg, k.additionalArguments); err != nil {
		return nil, err
	}

	kubeletConfig.withVersionToggles(kubeletVersion, k.additionalArguments)
	kubeletConfig.withCloudProvider(cfg, k.additionalArguments)

	if featuregates.DefaultTrue(featuregates.DefaultReservedResources, cfg.Spec.FeatureGates) {
		kubeletConfig.withDefaultReservedResources()
	}

	if len(cfg.Spec.Kubelet.Labels) > 0 {
		var labelStrings []string
		for labelKey, label := range cfg.Spec.Kubelet.Labels {
			labelStrings = append(labelStrings, fmt.Sprintf("%s=%s", labelKey, label))
		}
		k.additionalArguments["node-labels"] = strings.Join(labelStrings, ",")
	}
	if len(cfg.Spec.Kubelet.Config.RegisterWithTaints) > 0 {
		// kubelet versions less than 1.23 cannot pass the register-with-taints
		// field cannot via the kubelet configuration.
		if semver.Compare(kubeletVersion, "v1.23.0") < 0 {
			var taintStrings []string
			for _, taint := range cfg.Spec.Kubelet.Config.RegisterWithTaints {
				taintStrings = append(taintStrings, fmt.Sprintf("%s=%s:%s", taint.Key, taint.Value, taint.Effect))
			}
			k.additionalArguments["register-with-taints"] = strings.Join(taintStrings, ",")
		}
	}

	return &kubeletConfig, nil
}

// WriteConfig writes the kubelet config to a file.
// This should only be used for kubelet versions < 1.28.
// Comments:
//   - kubeletConfigOverrides should be passed in the order of application
func (k *kubelet) writeKubeletConfigToFile(kubeletConfig []byte) error {
	configPath := path.Join(kubeletConfigRoot, kubeletConfigFile)
	k.additionalArguments["config"] = configPath

	zap.L().Info("Writing kubelet config to file..", zap.String("path", configPath))
	return util.WriteFileWithDir(configPath, kubeletConfig, kubeletConfigPerm)
}

// WriteKubeletConfigToDir writes the kubelet config to a directory for drop-in
// directory support. This is only supported on kubelet versions >= 1.28.
// see: https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/#kubelet-conf-d
func (k *kubelet) writeKubeletConfigToDir(kubeletConfig []byte) error {
	dirPath := path.Join(kubeletConfigRoot, kubeletConfigDir)
	k.additionalArguments["config-dir"] = dirPath

	zap.L().Info("Enabling kubelet config drop-in dir..")
	k.setEnv("KUBELET_CONFIG_DROPIN_DIR_ALPHA", "on")

	filePath := path.Join(dirPath, "10-defaults.conf")
	zap.L().Info("Writing kubelet config to drop-in file..", zap.String("path", filePath))
	return util.WriteFileWithDir(filePath, kubeletConfig, kubeletConfigPerm)
}

func getProviderId(availabilityZone, instanceId string) string {
	return fmt.Sprintf("aws:///%s/%s", availabilityZone, instanceId)
}

// Get the IP of the node depending on the ipFamily configured for the cluster
func getNodeIp(ctx context.Context, imdsClient *imds.Client, cfg *api.NodeConfig) (string, error) {
	ipFamily, err := api.GetCIDRIpFamily(cfg.Spec.Cluster.CIDR)
	if err != nil {
		return "", err
	}
	switch ipFamily {
	case api.IPFamilyIPv4:
		ipv4Response, err := imdsClient.GetMetadata(ctx, &imds.GetMetadataInput{
			Path: "local-ipv4",
		})
		if err != nil {
			return "", err
		}
		ip, err := io.ReadAll(ipv4Response.Content)
		if err != nil {
			return "", err
		}
		return string(ip), nil
	case api.IPFamilyIPv6:
		ipv6Response, err := imdsClient.GetMetadata(ctx, &imds.GetMetadataInput{
			Path: fmt.Sprintf("network/interfaces/macs/%s/ipv6s", cfg.Status.Instance.MAC),
		})
		if err != nil {
			return "", err
		}
		ip, err := io.ReadAll(ipv6Response.Content)
		if err != nil {
			return "", err
		}
		return string(ip), nil
	default:
		return "", fmt.Errorf("invalid ip-family. %s is not one of %v", ipFamily, []api.IPFamily{api.IPFamilyIPv4, api.IPFamilyIPv6})
	}
}
