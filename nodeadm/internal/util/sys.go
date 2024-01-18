package util

import (
	"errors"
	"os"
	"os/exec"
	"strconv"
	"strings"
)

const trimChars = " \n\t"

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
