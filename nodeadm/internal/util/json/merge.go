package json

import (
	"encoding/json"
	"strings"

	"dario.cat/mergo"
)

var (
	jsonPrefix = ""
	jsonIndent = strings.Repeat(" ", 4)
)

func MarshalIndent(data any) ([]byte, error) {
	return json.MarshalIndent(data, jsonPrefix, jsonIndent)
}

// Merge merges two JSON documents.
// The fields in src will try to be applied onto dst
func Merge(dst string, src string) (*string, error) {
	dstMap := make(map[string]interface{})
	if err := json.Unmarshal([]byte(dst), &dstMap); err != nil {
		return nil, err
	}

	srcMap := make(map[string]interface{})
	if err := json.Unmarshal([]byte(src), &srcMap); err != nil {
		return nil, err
	}

	if err := mergo.Map(&dstMap, &srcMap, mergo.WithOverride); err != nil {
		return nil, err
	}
	mergedBytes, err := MarshalIndent(dstMap)
	if err != nil {
		return nil, err
	}
	merged := string(mergedBytes)

	return &merged, nil
}
