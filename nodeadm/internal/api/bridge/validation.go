package bridge

import (
	_ "embed"
	"errors"
	"fmt"
	"log"

	"k8s.io/apiextensions-apiserver/pkg/apihelpers"
	apiextensions "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions"
	apiextensionsv1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	apiservervalidation "k8s.io/apiextensions-apiserver/pkg/apiserver/validation"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/runtime/serializer"
)

//go:embed crds/node.eks.aws_nodeconfigs.yaml
var customResourceDefinitionYAML []byte

var customResourceDefinition *apiextensionsv1.CustomResourceDefinition

func init() {
	scheme := runtime.NewScheme()
	if err := apiextensions.AddToScheme(scheme); err != nil {
		panic("Failed to register apiextensions on validation scheme")
	}
	if err := apiextensionsv1.AddToScheme(scheme); err != nil {
		panic("Failed to register apiextensionsv1 on validation scheme")
	}
	codecs := serializer.NewCodecFactory(scheme)
	obj, gvk, err := codecs.UniversalDeserializer().Decode(customResourceDefinitionYAML, nil, nil)
	if err != nil {
		log.Fatalf("failed to decode CRD: %v", err)
	}
	if crd, ok := obj.(*apiextensionsv1.CustomResourceDefinition); !ok {
		log.Fatalf("CRD YAML is not a valid apiextensionsv1.CustomResourceDefinition: %v", gvk)
	} else {
		customResourceDefinition = crd
	}
}

func ValidateExternalType(obj runtime.Object, gvk schema.GroupVersionKind) error {
	validationSchema, err := apihelpers.GetSchemaForVersion(customResourceDefinition, gvk.Version)
	if err != nil {
		return err
	}
	var internalSchemaProps *apiextensions.JSONSchemaProps
	var internalValidationSchema *apiextensions.CustomResourceValidation
	if validationSchema != nil {
		internalValidationSchema = &apiextensions.CustomResourceValidation{}
		if err := apiextensionsv1.Convert_v1_CustomResourceValidation_To_apiextensions_CustomResourceValidation(validationSchema, internalValidationSchema, nil); err != nil {
			return fmt.Errorf("failed to convert CRD validation to internal version: %v", err)
		}
		internalSchemaProps = internalValidationSchema.OpenAPIV3Schema
	}
	validator, _, err := apiservervalidation.NewSchemaValidator(internalSchemaProps)
	if err != nil {
		return err
	}
	res := validator.Validate(obj)
	if len(res.Errors) > 0 {
		return errors.Join(res.Errors...)
	}
	return nil
}
