package install

import (
	"bytes"
	"context"
	_ "embed"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"golang.org/x/mod/semver"
)

const bucket = "amazon-eks"

const systemdUnitFilesDir = "/etc/systemd/system"

//go:embed kubelet.service
var kubeletServiceFileContent []byte

var (
	//go:embed hybrid-config.tpl
	awsConfigTplRaw string
	awsConfigTpl    = template.Must(template.New("").Parse(awsConfigTplRaw))
)

func Install(ctx context.Context, kubernetesMajorMinor string, cfg api.NodeConfig, awsCfg aws.Config) error {
	// We have to use us-west-2 for EKS artifacts.
	awsCfg.Region = "us-west-2"
	client := s3.NewFromConfig(awsCfg)

	// Find the latest patch release for the given major.minor
	ls, err := client.ListObjectsV2(ctx, &s3.ListObjectsV2Input{
		Bucket: aws.String(bucket),
		Prefix: aws.String(kubernetesMajorMinor),
	})
	if err != nil {
		return err
	}

	kubernetesVersion := "0.0.0"
	var kubernetesBuildDate string
	for _, v := range ls.Contents {
		// Key format: "1.27.1/2023-04-19/bin/linux/amd64/aws-iam-authenticator.sha256"
		keyParts := strings.Split(*v.Key, "/")

		if semver.Compare("v"+kubernetesVersion, "v"+keyParts[0]) < 0 {
			kubernetesVersion = keyParts[0]
			kubernetesBuildDate = keyParts[1]
		}
	}

	// Install binaries from latest Kube release.
	basePath := fmt.Sprintf("%s/%s/bin/linux/amd64", kubernetesVersion, kubernetesBuildDate)
	artifacts := map[string]string{
		"kubelet":                 "/usr/bin",
		"aws-iam-authenticator":   "/usr/local/bin",
		"ecr-credential-provider": "/etc/eks/image-credential-provider",
	}
	for artifact, installPath := range artifacts {
		if err := os.MkdirAll(installPath, os.ModeDir); err != nil {
			return err
		}

		fh, err := os.OpenFile(filepath.Join(installPath, artifact), os.O_CREATE|os.O_RDWR, 0755)
		if err != nil {
			return err
		}

		obj, err := client.GetObject(ctx, &s3.GetObjectInput{
			Bucket: aws.String(bucket),
			Key:    aws.String(strings.Join([]string{basePath, artifact}, "/")),
		})
		if err != nil {
			return err
		}

		_, err = io.Copy(fh, obj.Body)

		// Close immediately because we close when looping and if there's an error.
		obj.Body.Close()

		if err != nil {
			return err
		}
	}

	// Configure the systemd unit file.
	if err := os.MkdirAll(systemdUnitFilesDir, os.ModeDir); err != nil {
		return err
	}
	kubeletServiceFileBuf := bytes.NewBuffer(kubeletServiceFileContent)
	fh, err := os.OpenFile(filepath.Join(systemdUnitFilesDir, "kubelet.service"), os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return err
	}
	_, err = io.Copy(fh, kubeletServiceFileBuf)
	if err != nil {
		return err
	}
	fh.Close()

	// Configure the AWS config file.
	fh, err = os.OpenFile("/etc/eks/hybrid-config", os.O_CREATE|os.O_RDWR, 0644)
	if err != nil {
		return err
	}
	defer fh.Close()
	err = awsConfigTpl.Execute(fh, struct {
		AnchorARN  string
		ProfileARN string
		RoleARN    string
	}{
		AnchorARN:  cfg.Spec.Hybrid.Anywhere.AnchorARN,
		ProfileARN: cfg.Spec.Hybrid.Anywhere.ProfileARN,
		RoleARN:    cfg.Spec.Hybrid.Anywhere.RoleARN,
	})
	if err != nil {
		return err
	}
	fh.Close()

	// Install aws_signing_helper
	fh, err = os.OpenFile("/usr/local/bin/aws_signing_helper", os.O_CREATE|os.O_RDWR, 0755)
	if err != nil {
		return err
	}
	defer fh.Close()
	resp, err := http.Get("https://rolesanywhere.amazonaws.com/releases/1.1.1/X86_64/Linux/aws_signing_helper")
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	_, err = io.Copy(fh, resp.Body)
	if err != nil {
		return err
	}

	return nil
}
