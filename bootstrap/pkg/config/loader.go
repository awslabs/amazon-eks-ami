package config

import (
	"fmt"
	"os"

	"github.com/awslabs/amazon-eks-ami/bootstrap/pkg/apis"
	"github.com/awslabs/amazon-eks-ami/bootstrap/pkg/apis/bootstrapconfig/v1alpha1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/runtime/serializer"
)

var (
	scheme = runtime.NewScheme()
	codecs = serializer.NewCodecFactory(scheme)

	apiVersions = map[string]schema.GroupVersion{
		v1alpha1.SchemeGroupVersion.String(): v1alpha1.SchemeGroupVersion,
	}
)

func init() {
	v1alpha1.AddToScheme(scheme)
}

// LoadFromFile loads a BootstrapConfig from a file.
func LoadFromFile(path string) (*BootstrapConfig, error) {
	bytes, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return decode(bytes)
}

// decode decodes data into the internal BootstrapConfig type.
func decode(data []byte) (*BootstrapConfig, error) {
	obj, gvk, err := codecs.UniversalDecoder().Decode(data, nil, nil)
	if err != nil {
		return nil, err
	}

	if gvk.Kind != "BootstrapConfig" {
		return nil, fmt.Errorf("failed to decode %q (wrong Kind)", gvk.Kind)
	}

	if gvk.Group != apis.GroupName {
		return nil, fmt.Errorf("failed to decode BootstrapConfig, unexpected Group: %s", gvk.Group)
	}

	if internalConfig, ok := obj.(*BootstrapConfig); ok {
		return internalConfig, nil
	}

	return nil, fmt.Errorf("unable to convert %T to *BootstrapConfig", obj)
}
