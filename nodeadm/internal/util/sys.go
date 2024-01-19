package util

import (
	"errors"
	"io/fs"
	"os"
	"os/exec"
	"path"
	"strconv"
	"strings"
)

const trimChars = " \n\t"

// Wraps os.WriteFile to automatically create parent directories such that the
// caller does not need to ensure the existence of the file's directory
func WriteFileWithDir(filePath string, data []byte, perm fs.FileMode) error {
	if err := os.MkdirAll(path.Dir(filePath), perm); err != nil {
		return err
	}
	return os.WriteFile(filePath, data, perm)
}

func isHostPresent(host string) (bool, error) {
	output, err := exec.Command("getent", "hosts", host).Output()
	if err != nil {
		return false, err
	}
	present := len(output) > 0
	return present, nil
}

// Returns whether FIPS module is both installed an enabled on the system
//
//	ipsInstalled, fipsEnabled, err := getFipsInfo()
func getFipsInfo() (bool, bool, error) {
	fipsEnabledBytes, err := os.ReadFile("/proc/sys/crypto/fips_enabled")
	if errors.Is(err, os.ErrNotExist) {
		return false, false, nil
	} else if err != nil {
		return false, false, err
	}
	fipsEnabledInt, err := strconv.Atoi(strings.Trim(string(fipsEnabledBytes), trimChars))
	if err != nil {
		return true, false, err
	}
	return true, fipsEnabledInt == 1, nil
}
