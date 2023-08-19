package v1alpha1

import (
	"github.com/awslabs/amazon-eks-ami/bootstrap/pkg/apis"
	runtime "k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

// SchemeGroupVersion is group version used to register these objects
var SchemeGroupVersion = schema.GroupVersion{Group: apis.GroupName, Version: "v1alpha1"}

var (
	SchemeBuilder      runtime.SchemeBuilder
	localSchemeBuilder = &SchemeBuilder
	AddToScheme        = localSchemeBuilder.AddToScheme
)

func init() {
	localSchemeBuilder.Register(addKnownTypes)
}

// Adds the list of known types to the given scheme.
func addKnownTypes(scheme *runtime.Scheme) error {
	scheme.AddKnownTypes(SchemeGroupVersion,
		&BootstrapConfig{},
	)

	//	scheme.AddKnownTypes(SchemeGroupVersion,
	//		&metav1.Status{},
	//	)
	//	metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
	return nil
}
