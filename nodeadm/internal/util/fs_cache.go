package util

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
)

type FSCache interface {
	Read(key string) (string, error)
	Write(key, value string) error
	Keys() ([]string, error)
}

func NewFSCache(cacheDir string) *fsCache {
	return &fsCache{
		cacheDir: cacheDir,
	}
}

type fsCache struct {
	cacheDir string
}

func (b *fsCache) cachePath(key string) string {
	return filepath.Join(b.cacheDir, key)
}

func (b *fsCache) Read(key string) (string, error) {
	interfaceManagerBytes, err := os.ReadFile(b.cachePath(key))
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(interfaceManagerBytes)), nil
}

func (b *fsCache) Write(key, value string) error {
	return WriteFileWithDir(b.cachePath(key), []byte(value), 0644)
}

func (b *fsCache) Keys() ([]string, error) {
	paths, err := os.ReadDir(b.cacheDir)
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return nil, err
	}
	var keys []string
	for _, path := range paths {
		keys = append(keys, path.Name())
	}
	return keys, nil
}
