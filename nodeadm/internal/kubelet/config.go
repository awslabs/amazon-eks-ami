package kubelet

import (
	"context"
	_ "embed"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path"
	"time"

	"go.uber.org/zap"
	"golang.org/x/mod/semver"

	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	logsapi "k8s.io/component-base/logs/api/v1"
	k8skubelet "k8s.io/kubelet/config/v1beta1"

	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/aws/aws-sdk-go/service/eks"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	featuregates "github.com/awslabs/amazon-eks-ami/nodeadm/internal/feature-gates"
	jsonutil "github.com/awslabs/amazon-eks-ami/nodeadm/internal/util/json"
)

const (
	kubeletConfigRoot = "/etc/kubernetes/kubelet"
	kubeletConfigFile = "config.json"
	kubeletConfigDir  = "config.json.d"
	kubeletConfigPerm = 0644
)

func (k *kubelet) writeKubeletConfig(cfg *api.NodeConfig) error {
	kubeletConfig, err := k.generateKubeletConfig(cfg)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(kubeletConfigRoot, kubeletConfigPerm); err != nil {
		return err
	}
	return k.writeKubeletConfigToFile(&cfg.Spec.Kubelet, string(kubeletConfig))
}

func (k *kubelet) generateKubeletConfig(cfg *api.NodeConfig) ([]byte, error) {
	// hack to get around false/true ptrs
	trueVal, falseVal := true, false

	kubeletConfig := k8skubelet.KubeletConfiguration{
		TypeMeta: v1.TypeMeta{
			Kind:       "KubeletConfiguration",
			APIVersion: "kubelet.config.k8s.io/v1beta1",
		},
		Address: "0.0.0.0",
		Authentication: k8skubelet.KubeletAuthentication{
			Anonymous: k8skubelet.KubeletAnonymousAuthentication{Enabled: &falseVal},
			Webhook: k8skubelet.KubeletWebhookAuthentication{
				Enabled:  &trueVal,
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
		SerializeImagePulls: &falseVal,
		ServerTLSBootstrap:  true,
		TLSCipherSuites: []string{
			"TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
			"TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
			"TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305",
			"TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
			"TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305",
			"TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
			"TLS_RSA_WITH_AES_256_GCM_SHA384",
			"TLS_RSA_WITH_AES_128_GCM_SHA256",
		},
		ClusterDNS: []string{cfg.Spec.Cluster.DNSAddress},
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
	zap.L().Info("Got kubelet version", zap.String("version", kubeletVersion))

	nodeIp, err := getNodeIp(cfg)
	if err != nil {
		return nil, err
	}
	zap.L().Info("Detected IP setup for node", zap.String("ip", nodeIp))

	// default system kubelet arguments
	cfg.Spec.Kubelet.AdditionalArguments["image-credential-provider-config"] = "/etc/eks/image-credential-provider/config.json"
	cfg.Spec.Kubelet.AdditionalArguments["image-credential-provider-bin-dir"] = "/etc/eks/image-credential-provider"
	cfg.Spec.Kubelet.AdditionalArguments["node-ip"] = nodeIp

	// TODO: remove when 1.26 is EOL
	// --container-runtime flag is gone in 1.27+
	if semver.Compare(kubeletVersion, "v1.27.0") < 0 {
		cfg.Spec.Kubelet.AdditionalArguments["container-runtime"] = "remote"
	}

	// TODO: Remove this during 1.27 EOL
	// Enable Feature Gate for KubeletCredentialProviders in versions less than 1.28 since this feature flag was removed in 1.28.
	if semver.Compare(kubeletVersion, "v1.28.0") < 0 {
		kubeletConfig.FeatureGates["KubeletCredentialProviders"] = true
	}

	// for K8s versions that suport API Priority & Fairness, increase our API server QPS
	// in 1.27, the default is already increased to 50/100, so use the higher defaults
	if semver.Compare(kubeletVersion, "v1.27.0") < 0 && semver.Compare(kubeletVersion, "v1.22.0") >= 0 {
		*kubeletConfig.KubeAPIQPS = 10
		kubeletConfig.KubeAPIBurst = 20
	}

	// configure cloud provider
	if semver.Compare(kubeletVersion, "v1.26.0") < 0 {
		// TODO: remove when 1.25 is EOL
		cfg.Spec.Kubelet.AdditionalArguments["cloud-provider"] = "aws"
	} else {
		// ref: https://github.com/kubernetes/kubernetes/pull/121367
		cfg.Spec.Kubelet.AdditionalArguments["cloud-provider"] = "external"

		// provider ID needs to be specified when the cloud provider is
		// external. evaluate if this can be done within the cloud controller,
		// but since the values are coming from IMDS this might not be feasible
		kubeletConfig.ProviderID = getProviderId(cfg.Status.Instance.AvailabilityZone, cfg.Status.Instance.ID)

		// When the external cloud provider is used, kubelet will use /etc/hostname as the name of the Node object.
		// If the VPC has a custom `domain-name` in its DHCP options set, and the VPC has `enableDnsHostnames` set to `true`,
		// then /etc/hostname is not the same as EC2's PrivateDnsName.
		// The name of the Node object must be equal to EC2's PrivateDnsName for the aws-iam-authenticator to allow this kubelet to manage it.

		// hostname, err := getHostname()
		// if err != nil {
		// 	return nil, err
		// }
		// cfg.Spec.Kubelet.AdditionalArguments["hostname-override"] = hostname
		// cfg.Spec.Kubelet.AdditionalArguments["hostname-override"] = cfg.Status.Instance.ID
	}

	// When the DefaultReservedResources flag is enabled, override the kubelet
	// config with reserved cgroup values on behalf of the user
	if featuregates.DefaultTrue(featuregates.DefaultReservedResources, cfg.Spec.FeatureGates) {
		kubeletConfig.SystemReservedCgroup = "/system"
		kubeletConfig.KubeReservedCgroup = "/runtime"
	}

	// When the ComputeMaxPods feature gate is enabled, override the maxPods
	// value with a dynamic calculation of the eni limit using ec2 instance-type data
	if featuregates.DefaultFalse(featuregates.ComputeMaxPods, cfg.Spec.FeatureGates) {
		maxPods, err := calculateMaxPods(cfg.Status.Instance.Type, "v1.10.0", false, false, -1)
		if err != nil {
			return nil, err
		}
		kubeletConfig.MaxPods = int32(maxPods)
		zap.L().Info("Calculated maxPods value", zap.Int("maxPods", maxPods))
	}

	// TODO: setup resources based on maxPods
	if false {
		kubeletConfig.KubeReserved["cpu"] = fmt.Sprintf("%dm", getCpuMillicoresToReserve())
		kubeletConfig.KubeReserved["memory"] = fmt.Sprintf("%dMi", getMemoryMebibytesToReserve())
		kubeletConfig.KubeReserved["ephemeral-storage"] = "1Gi"
	}

	kubeletConfigData, err := jsonutil.MarshalIndent(kubeletConfig)
	if err != nil {
		return nil, err
	}
	return kubeletConfigData, nil
}

// # Helper function which calculates the amount of the given resource (either CPU or memory)
// # to reserve in a given resource range, specified by a start and end of the range and a percentage
// # of the resource to reserve. Note that we return zero if the start of the resource range is
// # greater than the total resource capacity on the node. Additionally, if the end range exceeds the total
// # resource capacity of the node, we use the total resource capacity as the end of the range.
// # Args:
// #   $1 total available resource on the worker node in input unit (either millicores for CPU or Mi for memory)
// #   $2 start of the resource range in input unit
// #   $3 end of the resource range in input unit
// #   $4 percentage of range to reserve in percent*100 (to allow for two decimal digits)
// # Return:
// #   amount of resource to reserve in input unit
//
//	get_resource_to_reserve_in_range() {
//	  local total_resource_on_instance=$1
//	  local start_range=$2
//	  local end_range=$3
//	  local percentage=$4
//	  resources_to_reserve="0"
//	  if (($total_resource_on_instance > $start_range)); then
//	    resources_to_reserve=$(((($total_resource_on_instance < $end_range ? $total_resource_on_instance : $end_range) - $start_range) * $percentage / 100 / 100))
//	  fi
//	  echo $resources_to_reserve
//	}
//
// # Calculates the amount of memory to reserve for kubeReserved in mebibytes. KubeReserved is a function of pod
// # density so we are calculating the amount of memory to reserve for Kubernetes systems daemons by
// # considering the maximum number of pods this instance type supports.
// # Args:
// #   $1 the max number of pods per instance type (MAX_PODS) based on values from /etc/eks/eni-max-pods.txt
// # Return:
// #   memory to reserve in Mi for the kubelet
func getMemoryMebibytesToReserve() int {
	//	  local max_num_pods=$1
	//	  memory_to_reserve=$((11 * $max_num_pods + 255))
	//	  echo $memory_to_reserve
	return 0
}

// Calculates the amount of CPU to reserve for kubeReserved in millicores from the total number of vCPUs available on the instance.
// From the total core capacity of this worker node, we calculate the CPU resources to reserve by reserving a percentage
// of the available cores in each range up to the total number of cores available on the instance.
// We are using these CPU ranges from GKE (https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-architecture#node_allocatable):
// 6% of the first core
// 1% of the next core (up to 2 cores)
// 0.5% of the next 2 cores (up to 4 cores)
// 0.25% of any cores above 4 cores
// Return:
//
//	CPU resources to reserve in millicores (m)
func getCpuMillicoresToReserve() int {
	// local total_cpu_on_instance=$(($(nproc) * 1000))
	// local cpu_ranges=(0 1000 2000 4000 $total_cpu_on_instance)
	// local cpu_percentage_reserved_for_ranges=(600 100 50 25)
	// cpu_to_reserve="0"
	// for i in "${!cpu_percentage_reserved_for_ranges[@]}"; do
	//
	//	local start_range=${cpu_ranges[$i]}
	//	local end_range=${cpu_ranges[(($i + 1))]}
	//	local percentage_to_reserve_for_range=${cpu_percentage_reserved_for_ranges[$i]}
	//	cpu_to_reserve=$(($cpu_to_reserve + $(get_resource_to_reserve_in_range $total_cpu_on_instance $start_range $end_range $percentage_to_reserve_for_range)))
	//
	// done
	// echo $cpu_to_reserve
	return 0
}

// WriteConfig writes the kubelet config to a file.
// This should only be used for kubelet versions < 1.28.
// Comments:
//   - kubeletConfigOverrides should be passed in the order of application
func (k *kubelet) writeKubeletConfigToFile(ko *api.KubeletOptions, defaultKubeletConfig string) error {
	config, err := func() (*string, error) {
		var userConfig *string
		if ko.Config.Inline != "" {
			userConfig = &ko.Config.Inline
		} else if ko.Config.Source != "" {
			zap.L().Error("Config source mode is not implemented, using default config")
		}

		if userConfig != nil {
			if config, err := jsonutil.Merge(defaultKubeletConfig, *userConfig); err != nil {
				return nil, err
			} else {
				return config, nil
			}
		} else {
			return &defaultKubeletConfig, nil
		}
	}()
	if err != nil {
		return err
	}

	configPath := path.Join(kubeletConfigRoot, kubeletConfigFile)
	if err := os.MkdirAll(path.Dir(configPath), kubeletConfigPerm); err != nil {
		return err
	}

	ko.AdditionalArguments["config"] = configPath

	zap.L().Info("Writing kubelet config to file..", zap.String("path", configPath))
	return os.WriteFile(configPath, []byte(*config), kubeletConfigPerm)
}

// WriteKubeletConfigToDir writes the kubelet config to a directory for drop-in
// directory support. This is only supported on kubelet versions >= 1.28.
// see: https://kubernetes.io/docs/tasks/administer-cluster/kubelet-config-file/#kubelet-conf-d
func (k *kubelet) writeKubeletConfigToDir(cfg *api.NodeConfig, defaultKubeletConfig, systemKubeletOverrides string) error {
	configs := make(map[string]string)
	if cfg.Spec.Kubelet.Config.MergeWithDefaults {
		configs["10-defaults.conf"] = defaultKubeletConfig
	}
	if cfg.Spec.Kubelet.Config.Inline != "" {
		configs["20-inline.conf"] = cfg.Spec.Kubelet.Config.Inline
	}
	if systemKubeletOverrides != "" {
		configs["30-system.conf"] = systemKubeletOverrides
	}

	dirPath := path.Join(kubeletConfigRoot, kubeletConfigDir)
	if err := os.MkdirAll(dirPath, kubeletConfigPerm); err != nil {
		return err
	}

	zap.L().Info("Enabling kubelet config drop-in dir..")
	k.setEnv("KUBELET_CONFIG_DROPIN_DIR_ALPHA", "on")

	cfg.Spec.Kubelet.AdditionalArguments["config-dir"] = dirPath

	for fileName, data := range configs {
		filePath := path.Join(dirPath, fileName)
		zap.L().Info("Writing kubelet config to drop-in file..", zap.String("path", filePath), zap.String("config", data))
		if err := os.WriteFile(filePath, []byte(data), kubeletConfigPerm); err != nil {
			return err
		}
	}
	return nil
}

func getHostname() (string, error) {
	imdsClient := imds.New(imds.Options{})
	hostnameResponse, err := imdsClient.GetMetadata(context.TODO(), &imds.GetMetadataInput{Path: "local-hostname"})
	if err != nil {
		return "", err
	}
	hostname, err := io.ReadAll(hostnameResponse.Content)
	if err != nil {
		return "", err
	}
	return string(hostname), nil
}

func getProviderId(availabilityZone, instanceId string) string {
	return fmt.Sprintf("aws:///%s/%s", availabilityZone, instanceId)
}

// Get the IP of the node depending on the ipFamily configured for the cluster
func getNodeIp(cfg *api.NodeConfig) (string, error) {
	imdsClient := imds.New(imds.Options{})
	switch cfg.Spec.Cluster.IPFamily {
	case eks.IpFamilyIpv4:
		ipv4Response, err := imdsClient.GetMetadata(context.TODO(),
			&imds.GetMetadataInput{Path: "local-ipv4"})
		if err != nil {
			return "", err
		}
		ip, err := io.ReadAll(ipv4Response.Content)
		if err != nil {
			return "", err
		}
		return string(ip), nil
	case eks.IpFamilyIpv6:
		ipv6Response, err := imdsClient.GetMetadata(context.TODO(),
			&imds.GetMetadataInput{Path: fmt.Sprintf("network/interfaces/macs/%s/ipv6s", cfg.Status.Instance.MAC)})
		if err != nil {
			return "", err
		}
		ip, err := io.ReadAll(ipv6Response.Content)
		if err != nil {
			return "", err
		}
		return string(ip), nil
	default:
		return "", fmt.Errorf("invalid ip-family. %s is not one of %v", cfg.Spec.Cluster.IPFamily, eks.IpFamily_Values())
	}
}
