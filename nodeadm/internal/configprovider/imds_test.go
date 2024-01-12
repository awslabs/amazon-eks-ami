package configprovider

import (
	"strings"
	"testing"
)

const sampleUserData = `MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset=us-ascii

#!/bin/bash
/usr/bin/nodeadm init

--==MYBOUNDARY==
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
metadata:
  name: example
spec:
  cluster:
    name: my-cluster
    apiServerEndpoint: https://example.com
    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=

--==MYBOUNDARY==--`

func TestIMDSParser(t *testing.T) {
	if _, err := parseMIMEUserData(strings.NewReader(sampleUserData)); err != nil {
		t.Fatal(err)
	}
}
