package api

import (
	"encoding/json"
	"reflect"

	"dario.cat/mergo"
	"k8s.io/apimachinery/pkg/runtime"
)

// Merges two NodeConfigs with custom collision handling
func (dst *NodeConfig) Merge(src *NodeConfig) error {
	return mergo.Merge(dst, src, mergo.WithOverride, mergo.WithTransformers(kubeletTransformer{}))
}

const (
	kubeletFlagsName  = "Flags"
	kubeletConfigName = "Config"
)

type kubeletTransformer struct{}

func (k kubeletTransformer) Transformer(typ reflect.Type) func(dst, src reflect.Value) error {
	if typ == reflect.TypeOf(KubeletOptions{}) {
		return func(dst, src reflect.Value) error {
			k.transformFlags(
				dst.FieldByName(kubeletFlagsName),
				src.FieldByName(kubeletFlagsName),
			)

			if err := k.transformConfig(
				dst.FieldByName(kubeletConfigName),
				src.FieldByName(kubeletConfigName),
			); err != nil {
				return err
			}

			return nil
		}
	}
	return nil
}

func (k kubeletTransformer) transformFlags(dst, src reflect.Value) {
	if dst.CanSet() {
		// due to the nature of how kubelet flags are parsed, if src flags come
		// after dst flags then they will have higher precedence. For
		// single-value flags this is equivalent to a replacement, but for flags
		// with multiple values like `--node-labels`, the values from every
		// instance will be merged with precedence based on order.
		//
		// Based on this behavior, we choose to explicitly appending slice for
		// this field and no others.
		dst.Set(reflect.AppendSlice(dst, src))
	}
}

func (k kubeletTransformer) transformConfig(dst, src reflect.Value) error {
	if dst.CanSet() {
		if dst.Len() <= 0 {
			// if the destination is empty, then just use the incoming data
			dst.Set(src)
		} else if src.Len() > 0 {
			// kubelet config in an inline document here, so we explicitly
			// perform a merge with dst and src data.
			dstConfigBytes, err := json.Marshal(dst.Interface())
			if err != nil {
				return err
			}
			srcConfigBytes, err := json.Marshal(src.Interface())
			if err != nil {
				return err
			}
			var dstConfigMap, srcConfigMap map[string]interface{}
			if err := json.Unmarshal(dstConfigBytes, &dstConfigMap); err != nil {
				return err
			}
			if err := json.Unmarshal(srcConfigBytes, &srcConfigMap); err != nil {
				return err
			}
			if err := mergo.Merge(&dstConfigMap, &srcConfigMap, mergo.WithOverride); err != nil {
				return err
			}
			_, err = json.MarshalIndent(dstConfigMap, "", "    ")
			if err != nil {
				return err
			}
			dst.Set(reflect.ValueOf(map[string]runtime.RawExtension{}))
		}
	}
	return nil
}
