package util

import (
	"errors"
	"io/fs"
	"os"
	"path"
)

// Wraps os.WriteFile to automatically create parent directories such that the
// caller does not need to ensure the existence of the file's directory
func WriteFileWithDir(filePath string, data []byte, perm fs.FileMode) error {
	if err := os.MkdirAll(path.Dir(filePath), perm); err != nil {
		return err
	}
	return os.WriteFile(filePath, data, perm)
}

// IsFilePathExists checks whether specific file path exists
func IsFilePathExists(filePath string) (bool, error) {
	_, err := os.Stat(filePath)
	if err == nil {
		return true, nil
	}
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	return false, err
}
