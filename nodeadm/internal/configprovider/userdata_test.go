package configprovider

import (
	"fmt"
	"mime/multipart"
	"net/mail"
	"strings"
	"testing"
)

const boundary = "#"
const nodeConfig = `---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
metadata:
  name: example
spec:
  cluster:
    name: my-cluster
    apiServerEndpoint: https://example.com
    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=`

var (
	sampleMIMEMultipartUserData = fmt.Sprintf(`MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="#"

--#
Content-Type: text/x-shellscript; charset=us-ascii

#!/bin/bash
/usr/bin/nodeadm init

--#
Content-Type: application/node.eks.aws

%s

--#--`, nodeConfig)
)

func TestMIMEParser(t *testing.T) {
	mimeMessage, err := mail.ReadMessage(strings.NewReader(sampleMIMEMultipartUserData))
	if err != nil {
		t.Fatal(err)
	}
	userDataReader := multipart.NewReader(mimeMessage.Body, boundary)
	if _, err := parseMultipart(userDataReader); err != nil {
		t.Fatal(err)
	}
}

func TestGetMIMEReader(t *testing.T) {
	if _, err := getMIMEMultipartReader([]byte(sampleMIMEMultipartUserData)); err != nil {
		t.Fatal(err)
	}
	if _, err := getMIMEMultipartReader([]byte(nodeConfig)); err == nil {
		t.Fatalf("expected err for bad multipart data")
	}
}
