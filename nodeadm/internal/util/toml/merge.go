package toml

import (
	toml "github.com/pelletier/go-toml/v2"
)

// Merge merges two TOML documents.
func Merge(a string, b string) (*string, error) {
	var merged map[string]interface{}
	toml.Unmarshal([]byte(a), &merged)
	toml.Unmarshal([]byte(b), &merged)
	bytes, err := toml.Marshal(merged)
	if err != nil {
		return nil, err
	}
	s := string(bytes)
	return &s, nil
}
