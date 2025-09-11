package bridge

import (
	"fmt"

	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/serializer"
)

// EncodeNodeConfig marshals the given internal NodeConfig object to JSON.
// JSON is used because it's simply easier than YAML to work with in scripting contexts.
func EncodeNodeConfig(nodeConfig *internalapi.NodeConfig) ([]byte, error) {
	scheme := runtime.NewScheme()
	err := localSchemeBuilder.AddToScheme(scheme)
	if err != nil {
		return nil, err
	}
	codecs := serializer.NewCodecFactory(scheme)
	info, matched := runtime.SerializerInfoForMediaType(codecs.SupportedMediaTypes(), runtime.ContentTypeJSON)
	if !matched {
		return nil, fmt.Errorf("JSON did not match any supported media type")
	}
	// always encode to the internal version so we don't lose any internal state
	codec := codecs.EncoderForVersion(info.Serializer, internalGroupVersion)
	return runtime.Encode(codec, nodeConfig)
}
