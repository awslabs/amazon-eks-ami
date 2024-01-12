package util

import "os/exec"

func isHostPresent(host string) (bool, error) {
	output, err := exec.Command("getent", "hosts", host).Output()
	if err != nil {
		return false, err
	}
	present := len(output) > 0
	return present, nil
}

func isFipsEnabled() (bool, error) {
	// shell out to sysctl to check if fips has been enabled
	fipsEnabledOutput, err := exec.Command("sysctl", "-n", "crypto.fips_enabled").Output()
	if err != nil {
		return false, err
	}
	fipsEnabled := string(fipsEnabledOutput) == "1"
	return fipsEnabled, nil
}
