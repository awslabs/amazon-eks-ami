package api

import (
	"encoding/json"
	"reflect"

	"dario.cat/mergo"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"k8s.io/apimachinery/pkg/runtime"
)

// Merges two NodeConfigs with custom collision handling
func (dst *NodeConfig) Merge(src *NodeConfig) error {
	return mergo.Merge(dst, src, mergo.WithOverride, mergo.WithTransformers(nodeConfigTransformer{}))
}

const (
	kubeletFlagsName     = "Flags"
	kubeletConfigName    = "Config"
	containerdConfigName = "Config"
)

type nodeConfigTransformer struct{}

func (k nodeConfigTransformer) Transformer(typ reflect.Type) func(dst, src reflect.Value) error {
	if typ == reflect.TypeOf(KubeletOptions{}) {
		return func(dst, src reflect.Value) error {
			transformKubeletFlags(
				dst.FieldByName(kubeletFlagsName),
				src.FieldByName(kubeletFlagsName),
			)
			return transformKubeletConfig(
				dst.FieldByName(kubeletConfigName),
				src.FieldByName(kubeletConfigName),
			)
		}
	} else if typ == reflect.TypeOf(ContainerdOptions{}) {
		return func(dst, src reflect.Value) error {
			return transformContainerdConfig(
				dst.FieldByName(containerdConfigName),
				src.FieldByName(containerdConfigName),
			)
		}
	}
	return nil
}

func transformKubeletFlags(dst, src reflect.Value) {
	if dst.CanSet() {
		// kubelet flags are parsed using https://github.com/spf13/pflag, where
		// flag order determines precedence. For single-value flags this is
		// equivalent to latter values overriding former ones, but for flags
		// with multiple values like `--node-labels`, the values from every
		// instance will be merged with precedence based on order.
		//
		// Based on this behavior, we choose to explicitly append slices for
		// this field and no other slices.
		dst.Set(reflect.AppendSlice(dst, src))
	}
}

func transformKubeletConfig(dst, src reflect.Value) error {
	if dst.CanSet() {
		if dst.Len() <= 0 {
			// if the destination is empty just use the source data
			dst.Set(src)
		} else if src.Len() > 0 {
			// kubelet config in an inline document here, so we explicitly
			// perform a merge with dst and src data.
			mergedMap, err := util.DocumentMerge(dst.Interface(), src.Interface(), mergo.WithOverride)
			if err != nil {
				return err
			}
			rawMap, err := toInlineDocument(mergedMap)
			if err != nil {
				return err
			}
			dst.Set(reflect.ValueOf(rawMap))
		}
	}
	return nil
}

func toInlineDocument(m map[string]interface{}) (InlineDocument, error) {
	var rawMap = make(InlineDocument)
	for key, value := range m {
		rawBytes, err := json.Marshal(value)
		if err != nil {
			return nil, err
		}
		rawMap[key] = runtime.RawExtension{Raw: rawBytes}
	}
	return rawMap, nil
}

func transformContainerdConfig(dst, src reflect.Value) error {
	if dst.CanSet() {
		if dst.Len() <= 0 {
			// if the destination is empty just use the source data
			dst.Set(src)
		} else if src.Len() > 0 {
			// TODO
			mergedToml := ""
			dst.SetString(mergedToml)
		}
	}
	return nil
}
