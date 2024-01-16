//go:build darwin

package daemon

import "io/fs"

// no-op implementations to keep the project buildable on macOS

func WriteSystemdServiceUnitDropIn(serviceName, fileName, fileContent string, filePerms fs.FileMode) error {
	return nil
}

func WriteSystemdServiceUnit(serviceName, unitContent string, filePerms fs.FileMode) error {
	return nil
}
