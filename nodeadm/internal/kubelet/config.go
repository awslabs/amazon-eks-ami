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

type kubeletSubConfig struct {
	v1.TypeMeta              `json:",inline"`
	Address                  string                           `json:"address"`
	Authentication           k8skubelet.KubeletAuthentication `json:"authentication"`
	Authorization            k8skubelet.KubeletAuthorization  `json:"authorization"`
	CgroupDriver             string                           `json:"cgroupDriver"`
	CgroupRoot               string                           `json:"cgroupRoot"`
	ClusterDomain            string                           `json:"clusterDomain"`
	ContainerRuntimeEndpoint string                           `json:"containerRuntimeEndpoint"`
	FeatureGates             map[string]bool                  `json:"featureGates"`
	HairpinMode              string                           `json:"hairpinMode"`
	ProtectKernelDefaults    bool                             `json:"protectKernelDefaults"`
	ReadOnlyPort             int                              `json:"readOnlyPort"`
	Logging                  logsapi.LoggingConfiguration     `json:"logging"`
	SerializeImagePulls      bool                             `json:"serializeImagePulls"`
	ServerTLSBootstrap       bool                             `json:"serverTLSBootstrap"`
	TLSCipherSuites          []string                         `json:"tlsCipherSuites"`
	ClusterDNS               []string                         `json:"clusterDNS"`

	SystemReservedCgroup *string `json:"systemReservedCgroup,omitempty"`
	KubeReservedCgroup   *string `json:"kubeReservedCgroup,omitempty"`
	ProviderID           *string `json:"providerID,omitempty"`
	KubeAPIQPS           *int    `json:"kubeAPIQPS,omitempty"`
	KubeAPIBurst         *int    `json:"kubeAPIBurst,omitempty"`
	MaxPods              *int    `json:"maxPods,omitempty"`
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

func (k *kubelet) GenerateKubeletConfig(cfg *api.NodeConfig) (*kubeletSubConfig, error) {
	clusterDns, err := util.GetClusterDns(&cfg.Spec.Cluster)
	if err != nil {
		return nil, err
	}

	kubeletConfig := kubeletSubConfig{
		TypeMeta: v1.TypeMeta{
			Kind:       "KubeletConfiguration",
			APIVersion: "kubelet.config.k8s.io/v1beta1",
		},
		Address: "0.0.0.0",
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
		ClusterDNS: []string{clusterDns},
	}

	// To support worker nodes to continue to communicate and connect to local cluster even when the Outpost
	// is disconnected from the parent AWS Region, the following specific setup are required:
	//    - append entries to /etc/hosts with the mappings of control plane host IP address and API server
	//      domain name. So that the domain name can be resolved to IP addresses locally.
	//    - use aws-iam-authenticator as bootstrap auth for kubelet TLS bootstrapping which downloads client
	//      X.509 certificate and generate kubelet kubeconfig file which uses the client cert. So that the
	//      worker node can be authentiacated through X.509 certificate which works for both connected and
	//      disconnected state.
	if enabled := cfg.Spec.Cluster.EnableOutpost; enabled != nil && *enabled {
		zap.L().Info("Setting up outpost..")

		if cfg.Spec.Cluster.ID == "" {
			return nil, fmt.Errorf("clusterId cannot be empty when outpost is enabled.")
		}
		apiUrl, err := url.Parse(cfg.Spec.Cluster.APIServerEndpoint)
		if err != nil {
			return nil, err
		}

		// TODO: cleanup
		output, err := exec.Command("getent", "hosts", apiUrl.Host).Output()
		if err != nil {
			return nil, err
		}

		// append to /etc/hosts file with shuffled mappings of "IP address to API server domain name"
		f, err := os.OpenFile("/etc/hosts", os.O_APPEND|os.O_WRONLY, kubeletConfigPerm)
		if err != nil {
			return nil, err
		}
		defer f.Close()
		if _, err := f.Write(output); err != nil {
			return nil, err
		}
	}

	// Get the kubelet/kubernetes version to help conditionally enable features
	kubeletVersion, err := GetKubeletVersion()
	if err != nil {
		return nil, err
	}
	zap.L().Info("Detected kubelet version", zap.String("version", kubeletVersion))

	nodeIp, err := getNodeIp(cfg)
	if err != nil {
		return nil, err
	}
	k.additionalArguments["node-ip"] = nodeIp
	zap.L().Info("Setup IP for node", zap.String("ip", nodeIp))

	// TODO: remove when 1.26 is EOL
	// --container-runtime flag is gone in 1.27+
	if semver.Compare(kubeletVersion, "v1.27.0") < 0 {
		k.additionalArguments["container-runtime"] = "remote"
	}

	// TODO: Remove this during 1.27 EOL
	// Enable Feature Gate for KubeletCredentialProviders in versions less than 1.28 since this feature flag was removed in 1.28.
	if semver.Compare(kubeletVersion, "v1.28.0") < 0 {
		kubeletConfig.FeatureGates["KubeletCredentialProviders"] = true
	}

	// for K8s versions that suport API Priority & Fairness, increase our API server QPS
	// in 1.27, the default is already increased to 50/100, so use the higher defaults
	if semver.Compare(kubeletVersion, "v1.27.0") < 0 && semver.Compare(kubeletVersion, "v1.22.0") >= 0 {
		kubeletConfig.KubeAPIQPS = ptr.Int(10)
		kubeletConfig.KubeAPIBurst = ptr.Int(20)
	}

	// configure cloud provider
	if semver.Compare(kubeletVersion, "v1.26.0") < 0 {
		// TODO: remove when 1.25 is EOL
		k.additionalArguments["cloud-provider"] = "aws"
	} else {
		// ref: https://github.com/kubernetes/kubernetes/pull/121367
		k.additionalArguments["cloud-provider"] = "external"

		// provider ID needs to be specified when the cloud provider is
		// external. evaluate if this can be done within the cloud controller.
		// since the values are coming from IMDS this might not be feasible
		providerId := getProviderId(cfg.Status.Instance.AvailabilityZone, cfg.Status.Instance.ID)
		kubeletConfig.ProviderID = &providerId

		// When the external cloud provider is used, kubelet will use /etc/hostname as the name of the Node object.
		// If the VPC has a custom `domain-name` in its DHCP options set, and the VPC has `enableDnsHostnames` set to `true`,
		// then /etc/hostname is not the same as EC2's PrivateDnsName.
		// The name of the Node object must be equal to EC2's PrivateDnsName for the aws-iam-authenticator to allow this kubelet to manage it.

		// k.additionalArguments["hostname-override"] = cfg.Status.Instance.ID
	}

	// When the DefaultReservedResources flag is enabled, override the kubelet
	// config with reserved cgroup values on behalf of the user
	if featuregates.DefaultTrue(featuregates.DefaultReservedResources, cfg.Spec.FeatureGates) {
		kubeletConfig.SystemReservedCgroup = ptr.String("/system")
		kubeletConfig.KubeReservedCgroup = ptr.String("/runtime")
	}

	return &kubeletConfig, nil
}

// WriteConfig writes the kubelet config to a file.
// This should only be used for kubelet versions < 1.28.
// Comments:
//   - kubeletConfigOverrides should be passed in the order of application
func (k *kubelet) writeKubeletConfigToFile(kubeletConfig []byte) error {
	configPath := path.Join(kubeletConfigRoot, kubeletConfigFile)
	if err := os.MkdirAll(path.Dir(configPath), kubeletConfigPerm); err != nil {
		return err
	}

	k.additionalArguments["config"] = configPath

	zap.L().Info("Writing kubelet config to file..", zap.String("path", configPath))
	return os.WriteFile(configPath, kubeletConfig, kubeletConfigPerm)
}

// WriteKubeletConfigToDir writes the kubelet config to a directory for drop-in
// directory support. This is only supported on kubelet versions >= 1.28.
// see: https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/#kubelet-conf-d
func (k *kubelet) writeKubeletConfigToDir(kubeletConfig []byte) error {
	dirPath := path.Join(kubeletConfigRoot, kubeletConfigDir)
	if err := os.MkdirAll(dirPath, kubeletConfigPerm); err != nil {
		return err
	}

	k.additionalArguments["config-dir"] = dirPath

	zap.L().Info("Enabling kubelet config drop-in dir..")
	k.setEnv("KUBELET_CONFIG_DROPIN_DIR_ALPHA", "on")

	filePath := path.Join(dirPath, "10-defaults.conf")
	zap.L().Info("Writing kubelet config to drop-in file..", zap.String("path", filePath))
	return os.WriteFile(filePath, kubeletConfig, kubeletConfigPerm)
}

func getProviderId(availabilityZone, instanceId string) string {
	return fmt.Sprintf("aws:///%s/%s", availabilityZone, instanceId)
}

// Get the IP of the node depending on the ipFamily configured for the cluster
func getNodeIp(cfg *api.NodeConfig) (string, error) {
	ipFamily, err := util.GetIpFamily(cfg.Spec.Cluster.CIDR)
	if err != nil {
		return "", err
	}
	switch ipFamily {
	case api.IPFamilyIPv4:
		imdsClient := imds.New(imds.Options{})
		ipv4Response, err := imdsClient.GetMetadata(context.TODO(), &imds.GetMetadataInput{
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
		imdsClient := imds.New(imds.Options{})
		ipv6Response, err := imdsClient.GetMetadata(context.TODO(), &imds.GetMetadataInput{
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
