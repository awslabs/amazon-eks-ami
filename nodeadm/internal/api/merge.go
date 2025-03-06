package api

import (
	"encoding/json"
	"reflect"

	"dario.cat/mergo"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/pelletier/go-toml/v2"
	"k8s.io/apimachinery/pkg/runtime"
)

// Merges two NodeConfigs with custom collision handling
func (dst *NodeConfig) Merge(src *NodeConfig) error {
	return mergo.Merge(dst, src, mergo.WithOverride, mergo.WithTransformers(nodeConfigTransformer{}))
}

type nodeConfigTransformer struct{}

func (t nodeConfigTransformer) Transformer(typ reflect.Type) func(dst, src reflect.Value) error {
	switch typ {
	case reflect.TypeOf(ContainerdConfig("")):
		return t.mergeContainerdConfig
	case reflect.TypeOf(KubeletFlags{}):
		return t.mergeKubeletFlags
	case reflect.TypeOf(InlineDocument{}):
		return t.mergeInlineDocument
	}
	return nil
}

func (t nodeConfigTransformer) mergeKubeletFlags(dst, src reflect.Value) error {
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
	return nil
}

func (t nodeConfigTransformer) mergeContainerdConfig(dst, src reflect.Value) error {
	if dst.CanSet() {
		if dst.Len() <= 0 {
			// if the destination is empty just use the source data
			dst.Set(src)
		} else if src.Len() > 0 {
			// containerd config is an inline string in TOML format
			configBytes, err := util.Merge(
				[]byte(dst.String()), []byte(src.String()),
				toml.Marshal, toml.Unmarshal,
			)
			if err != nil {
				return err
			}
			config, err := toml.Marshal(configBytes)
			if err != nil {
				return err
			}
			dst.SetString(string(config))
		}
	}
	return nil
}

func (t nodeConfigTransformer) mergeInlineDocument(dst, src reflect.Value) error {
	if dst.CanSet() {
		if dst.Len() <= 0 {
			// if the destination is empty just use the source data
			dst.Set(src)
		} else if src.Len() > 0 {
			mergedMap, err := util.Merge(
				dst.Interface(), src.Interface(),
				json.Marshal, json.Unmarshal,
			)
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
