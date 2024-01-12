package util

import (
	"context"
	"encoding/base64"
	"fmt"
	"io"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/aws/aws-sdk-go-v2/service/ecr"
)

// TODO: is dynamic?
const pauseContainerVersion = "3.5"

// Returns an authorization token string for ECR
func GetAuthorizationToken(awsRegion string) (string, error) {
	awsConfig, err := config.LoadDefaultConfig(context.Background(), config.WithRegion(awsRegion))
	if err != nil {
		return "", err
	}
	ecrClient := ecr.NewFromConfig(awsConfig)
	token, err := ecrClient.GetAuthorizationToken(context.Background(), &ecr.GetAuthorizationTokenInput{})
	if err != nil {
		return "", err
	}

	authData := token.AuthorizationData[0].AuthorizationToken
	data, err := base64.StdEncoding.DecodeString(*authData)
	if err != nil {
		return "", err
	}

	return string(data), nil
}

// Get the pause container image
func GetPauseContainer(awsRegion string) (string, error) {
	imdsClient := imds.New(imds.Options{})
	domainResponse, err := imdsClient.GetMetadata(context.TODO(), &imds.GetMetadataInput{Path: "services/domain"})
	if err != nil {
		return "", err
	}
	awsDomainBytes, err := io.ReadAll(domainResponse.Content)
	if err != nil {
		return "", err
	}
	awsDomain := string(awsDomainBytes)

	var account string
	switch awsRegion {
	case "ap-east-1":
		account = "800184023465"
	case "me-south-1":
		account = "558608220178"
	case "cn-north-1":
		account = "918309763551"
	case "cn-northwest-1":
		account = "961992271922"
	case "us-gov-west-1":
		account = "013241004608"
	case "us-gov-east-1":
		account = "151742754352"
	case "us-iso-west-1":
		account = "608367168043"
	case "us-iso-east-1":
		account = "725322719131"
	case "us-isob-east-1":
		account = "187977181151"
	case "af-south-1":
		account = "877085696533"
	case "ap-southeast-3":
		account = "296578399912"
	case "me-central-1":
		account = "759879836304"
	case "eu-south-1":
		account = "590381155156"
	case "eu-south-2":
		account = "455263428931"
	case "eu-central-2":
		account = "900612956339"
	case "ap-south-2":
		account = "900889452093"
	case "ap-southeast-4":
		account = "491585149902"
	case "il-central-1":
		account = "066635153087"
	case "ca-west-1":
		account = "761377655185"
	// This sections includes all commercial non-opt-in regions, which use
	// the same account for ECR pause container images, but still have in-region
	// registries.
	case
		"ap-northeast-1", "ap-northeast-2", "ap-northeast-3",
		"ap-south-1",
		"ap-southeast-1", "ap-southeast-2",
		"ca-central-1",
		"eu-central-1",
		"eu-north-1",
		"eu-west-1", "eu-west-2", "eu-west-3",
		"sa-east-1",
		"us-east-1", "us-east-2",
		"us-west-1", "us-west-2":
		account = "602401143452"
	// If the region is not mapped to an account, let's try to choose another region
	// in that partition.
	default:
		if strings.HasPrefix(awsRegion, "us-gov-") {
			account = "013241004608"
			awsRegion = "us-gov-west-1"
		} else if strings.HasPrefix(awsRegion, "cn-") {
			account = "961992271922"
			awsRegion = "cn-northwest-1"
		} else if strings.HasPrefix(awsRegion, "us-iso-") {
			account = "725322719131"
			awsRegion = "us-iso-east-1"
		} else if strings.HasPrefix(awsRegion, "us-isob-") {
			account = "187977181151"
			awsRegion = "us-isob-east-1"
		} else {
			account = "602401143452"
			awsRegion = "us-west-2"
		}
	}

	ecrDomain := assembleEcrDomain(account, "ecr", awsRegion, awsDomain)

	if fipsEnabled, err := isFipsEnabled(); err != nil {
		return "", err
	} else if fipsEnabled {
		ecrDomainFips := assembleEcrDomain(account, "ecr-fips", awsRegion, awsDomain)
		if present, err := isHostPresent(ecrDomainFips); err != nil {
			return "", err
		} else if present {
			ecrDomain = ecrDomainFips
		}
	}

	return fmt.Sprintf("%s/eks/pause:%s", ecrDomain, pauseContainerVersion), nil
}

func assembleEcrDomain(account, ecrEndpoint, region, awsDomain string) string {
	return fmt.Sprintf("%s.dkr.%s.%s.%s", account, ecrEndpoint, region, awsDomain)
}
