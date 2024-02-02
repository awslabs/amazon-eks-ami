package util

import (
	"context"
	"fmt"
	"io"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/ec2/imds"
	"github.com/aws/aws-sdk-go-v2/service/ecr"
)

// TODO: is dynamic?
const pauseContainerVersion = "3.5"

// Returns the base64 encoded authorization token string for ECR of the format "AWS:XXXXX"
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
	return *authData, nil
}

func GetAwsDomain(ctx context.Context, imdsClient *imds.Client) (string, error) {
	domainResponse, err := imdsClient.GetMetadata(ctx, &imds.GetMetadataInput{Path: "services/domain"})
	if err != nil {
		return "", err
	}
	awsDomainBytes, err := io.ReadAll(domainResponse.Content)
	if err != nil {
		return "", err
	}
	awsDomain := string(awsDomainBytes)
	return awsDomain, nil
}

// Get the pause container image
func GetPauseContainer(ecrUri string) (string, error) {
	return fmt.Sprintf("%s/eks/pause:%s", ecrUri, pauseContainerVersion), nil
}

type GetEcrUriRequest struct {
	Region    string
	Domain    string
	Account   string
	AllowFips bool
}

func GetEcrUri(r GetEcrUriRequest) (string, error) {
	if r.Account == "" {
		switch r.Region {
		case "ap-east-1":
			r.Account = "800184023465"
		case "me-south-1":
			r.Account = "558608220178"
		case "cn-north-1":
			r.Account = "918309763551"
		case "cn-northwest-1":
			r.Account = "961992271922"
		case "us-gov-west-1":
			r.Account = "013241004608"
		case "us-gov-east-1":
			r.Account = "151742754352"
		case "us-iso-west-1":
			r.Account = "608367168043"
		case "us-iso-east-1":
			r.Account = "725322719131"
		case "us-isob-east-1":
			r.Account = "187977181151"
		case "af-south-1":
			r.Account = "877085696533"
		case "ap-southeast-3":
			r.Account = "296578399912"
		case "me-central-1":
			r.Account = "759879836304"
		case "eu-south-1":
			r.Account = "590381155156"
		case "eu-south-2":
			r.Account = "455263428931"
		case "eu-central-2":
			r.Account = "900612956339"
		case "ap-south-2":
			r.Account = "900889452093"
		case "ap-southeast-4":
			r.Account = "491585149902"
		case "il-central-1":
			r.Account = "066635153087"
		case "ca-west-1":
			r.Account = "761377655185"
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
			r.Account = "602401143452"
		// If the region is not mapped to an account, let's try to choose another region
		// in that partition.
		default:
			if strings.HasPrefix(r.Region, "us-gov-") {
				r.Account = "013241004608"
				r.Region = "us-gov-west-1"
			} else if strings.HasPrefix(r.Region, "cn-") {
				r.Account = "961992271922"
				r.Region = "cn-northwest-1"
			} else if strings.HasPrefix(r.Region, "us-iso-") {
				r.Account = "725322719131"
				r.Region = "us-iso-east-1"
			} else if strings.HasPrefix(r.Region, "us-isob-") {
				r.Account = "187977181151"
				r.Region = "us-isob-east-1"
			} else {
				r.Account = "602401143452"
				r.Region = "us-west-2"
			}
		}
	}

	ecrUri := buildEcrUri(r.Account, "ecr", r.Region, r.Domain)

	if r.AllowFips {
		fipsInstalled, fipsEnabled, err := getFipsInfo()
		if err != nil {
			return "", err
		}
		if fipsInstalled && fipsEnabled {
			ecrUriFips := buildEcrUri(r.Account, "ecr-fips", r.Region, r.Domain)
			if present, err := isHostPresent(ecrUriFips); err != nil {
				return "", err
			} else if present {
				return ecrUriFips, nil
			}
		}
	}

	return ecrUri, nil
}

func buildEcrUri(account, ecrEndpoint, awsRegion, awsDomain string) string {
	return fmt.Sprintf("%s.dkr.%s.%s.%s", account, ecrEndpoint, awsRegion, awsDomain)
}
