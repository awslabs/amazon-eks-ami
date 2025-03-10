package ipamd

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"syscall"
)

const (
	eniInfoUrl = "http://localhost:61679/v1/enis"
)

var (
	ErrIPAMDNotAvailable = errors.New("ipamd not available")
)

// GetENIInfos retrieves ENI information from IPAMD's introspection API
// See: https://github.com/aws/amazon-vpc-cni-k8s/blob/de312d0dbfd2a4e9949892bf4a5418ac5ac97031/pkg/ipamd/introspect.go
func GetENIInfos() (*ENIInfos, error) {
	resp, err := http.Get(eniInfoUrl)
	if err != nil {
		// convert "connection refused" for simpler handling by callers
		var sysErr *os.SyscallError
		if errors.As(err, &sysErr) && sysErr.Err == syscall.ECONNREFUSED {
			return nil, ErrIPAMDNotAvailable
		}
		return nil, err
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var enis ENIInfos
	if err := json.Unmarshal(body, &enis); err != nil {
		return nil, err
	}
	return &enis, nil
}
