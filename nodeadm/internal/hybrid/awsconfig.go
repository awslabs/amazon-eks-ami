package hybrid

import (
	"context"
	"os"
	"path/filepath"
	"text/template"

	"github.com/aws/aws-sdk-go-v2/config"
)

var (
	rawTpl = `[hybrid]
credential_process = aws_signing_helper credential-process --certificate /etc/iam/pki/server.pem --private-key /etc/iam/pki/server.key --trust-anchor-arn {{ .TrustAnchorARN }} --profile-arn {{ .ProfileARN }} --role-arn {{ .RoleARN }}
`
	tpl = template.Must(template.New("").Parse(rawTpl))
)

type AWSConfig struct {
	TrustAnchorARN string
	ProfileARN     string
	Region         string
	Cert           string
	PrivateKey     string
}

func WriteAWSConfig(cfg AWSConfig) error {
	_, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(cfg.Region), config.WithSharedConfigProfile("hybrid"))
	if err != nil {
		return err
	}
	return nil

	// fh, err := openDefaultAWSConfig()
	// if err != nil {
	// 	return err
	// }
	// return tpl.Execute(fh, cfg)
}

func openDefaultAWSConfig() (*os.File, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	awsDir := filepath.Join(home, ".aws")

	_, err = os.Stat(awsDir)
	if os.IsNotExist(err) {
		if err := os.MkdirAll(awsDir, os.ModeDir); err != nil {
			return nil, err
		}
	} else if err != nil {
		return nil, err
	}

	fh, err := os.OpenFile(filepath.Join(awsDir, "config"), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return nil, err
	}

	return fh, nil
}
