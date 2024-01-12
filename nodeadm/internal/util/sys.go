package util

import (
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

func isFipsEnabled() (bool, error) {
	fipsEnabledBytes, err := os.ReadFile("/proc/sys/crypto/fips_enabled")
	if err != nil {
		return false, err
	}
	fipsEnabledInt, err := strconv.Atoi(strings.Trim(string(fipsEnabledBytes), trimChars))
	if err != nil {
		return false, err
	}
	return fipsEnabledInt == 1, nil
}

func GetNproc() (int, error) {
	nproc, err := exec.Command("nproc").Output()
	if err != nil {
		return 0, err
	}
	return strconv.Atoi(strings.Trim(string(nproc), trimChars))
}
