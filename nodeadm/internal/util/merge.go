package util

import (
	"fmt"
	"reflect"

	"dario.cat/mergo"
)

// Merge is a wrapper around the "Merge" from dario.cat/mergo which
// automatically handles repeated conversions between raw representations of
// data and nested key-value objects
//
// dst and src can either both be of type []byte, or both will be marshalled
// into a binary representation using the provided marshaller func.
func Merge(
	dst, src any,
	marshaller func(v any) ([]byte, error),
	unmarshaller func(data []byte, v any) error,
	opts ...func(*mergo.Config),
) (map[string]interface{}, error) {
	var (
		dstBytes, srcBytes []byte
		dstMap, srcMap     map[string]interface{}
		err                error
	)
	if reflect.TypeOf(dst) == reflect.TypeOf([]byte{}) && reflect.TypeOf(src) == reflect.TypeOf([]byte{}) {
		dstBytes = reflect.ValueOf(dst).Bytes()
		srcBytes = reflect.ValueOf(src).Bytes()
	} else {
		if marshaller == nil {
			return nil, fmt.Errorf("marshaller expected.")
		}
		if dstBytes, err = marshaller(dst); err != nil {
			return nil, err
		}
		if srcBytes, err = marshaller(src); err != nil {
			return nil, err
		}
	}
	if err := unmarshaller(dstBytes, &dstMap); err != nil {
		return nil, err
	}
	if err := unmarshaller(srcBytes, &srcMap); err != nil {
		return nil, err
	}
	if len(opts) == 0 {
		opts = append(opts, mergo.WithOverride)
	}
	if err := mergo.Merge(&dstMap, &srcMap, opts...); err != nil {
		return nil, err
	}
	return dstMap, nil
}
