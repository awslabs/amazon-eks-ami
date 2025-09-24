package bridge

import (
	"github.com/awslabs/amazon-eks-ami/nodeadm/api"
	"github.com/awslabs/amazon-eks-ami/nodeadm/api/v1alpha1"
	internalapi "github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

var (
	localSchemeBuilder = runtime.NewSchemeBuilder(
		v1alpha1.AddToScheme,
		addInternalTypes,
	)

	InternalGroupVersion = schema.GroupVersion{Group: api.GroupName, Version: runtime.APIVersionInternal}
)

func addInternalTypes(scheme *runtime.Scheme) error {
	scheme.AddKnownTypes(InternalGroupVersion,
		&internalapi.NodeConfig{},
	)
	return nil
}
