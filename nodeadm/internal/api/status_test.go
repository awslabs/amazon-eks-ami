package api

import (
	"context"
	"errors"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/aws/imds"
	"github.com/stretchr/testify/assert"
)

var (
	nonMulticardInstanceMac = `06:83:e7:fd:fd:fd/
`
	validNetworkInterfacesMacs = `06:83:e7:fe:fe:fe/
06:83:e7:ff:ff:ff/
`
	multicardNoIpOnOneCard = `06:83:e7:fb:fb:fb/
06:83:e7:fc:fc:fc/
06:83:e7:fc:fc:fd/
`
	validTwoNetworkCardDetails = []NetworkCardDetails{
		{MAC: "06:83:e7:fe:fe:fe", IpV4Address: "1.2.3.4", CardIndex: 1},
		{MAC: "06:83:e7:ff:ff:ff", IpV4Address: "5.6.7.8", CardIndex: 0},
	}

	validOneNetworkCardDetails = []NetworkCardDetails{
		{MAC: "06:83:e7:fb:fb:fb", IpV4Address: "1.2.3.4", CardIndex: 0},
	}
	imds404     = errors.New("http response error StatusCode: 404, request to EC2 IMDS failed")
	imdsGeneric = errors.New("IMDS error")
)

func mockGetPropertyImdsError(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	if prop == "network/interfaces/macs/" {
		return "", imdsGeneric
	}
	return "", nil
}

func mockGetPropertyNonMulticardInstance(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	if prop == "network/interfaces/macs/" {
		return nonMulticardInstanceMac, nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fd:fd:fd/network-card" {
		return "", imds404
	}
	return "", nil
}

func mockGetPropertyTwoValidCards(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	if prop == "network/interfaces/macs/" {
		return validNetworkInterfacesMacs, nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fe:fe:fe/network-card" {
		return "1", nil
	}
	if prop == "network/interfaces/macs/06:83:e7:ff:ff:ff/network-card" {
		return "0", nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fe:fe:fe/local-ipv4s" {
		return "1.2.3.4", nil
	}
	if prop == "network/interfaces/macs/06:83:e7:ff:ff:ff/local-ipv4s" {
		return "5.6.7.8", nil
	}

	return "", nil
}

func mockGetPropertyNoIp(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	if prop == "network/interfaces/macs/" {
		return multicardNoIpOnOneCard, nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fb:fb:fb/network-card" {
		return "0", nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fc:fc:fc/network-card" {
		return "1", nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fc:fc:fd/network-card" {
		return "2", nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fb:fb:fb/local-ipv4s" {
		return "1.2.3.4", nil
	}
	if prop == "network/interfaces/macs/06:83:e7:fc:fc:fc/local-ipv4s" {
		return "", imds404
	}
	if prop == "network/interfaces/macs/06:83:e7:fc:fc:fd/local-ipv4s" {
		return "", nil
	}

	return "", nil
}

func TestGetNetworkCardsDetails(t *testing.T) {

	tests := []struct {
		name                       string
		mockGetProperty            func(ctx context.Context, prop imds.IMDSProperty) (string, error)
		expectedNetworkCardDetails []NetworkCardDetails
		expectedError              error
	}{
		{
			name:                       "Success card 0 and card 1 available",
			mockGetProperty:            mockGetPropertyTwoValidCards,
			expectedNetworkCardDetails: validTwoNetworkCardDetails,
			expectedError:              nil,
		},
		{
			name:                       "Success non multicard instance",
			mockGetProperty:            mockGetPropertyNonMulticardInstance,
			expectedNetworkCardDetails: []NetworkCardDetails{},
			expectedError:              nil,
		},
		{
			name:                       "Success multicard instance no IP",
			mockGetProperty:            mockGetPropertyNoIp,
			expectedNetworkCardDetails: validOneNetworkCardDetails,
			expectedError:              nil,
		},
		{
			name:                       "Fail with IMDS error",
			mockGetProperty:            mockGetPropertyImdsError,
			expectedNetworkCardDetails: nil,
			expectedError:              errors.New("failed to get network interfaces from imds: IMDS error"),
		},
	}

	for _, test := range tests {
		t.Logf("Running test: %s", test.name)
		ctx := context.Background()
		networkCardDetails, err := getNetworkCardsDetails(ctx, test.mockGetProperty)

		assert.Equal(t, test.expectedNetworkCardDetails, networkCardDetails, t.Name())
		if test.expectedError != nil {
			assert.EqualError(t, err, test.expectedError.Error(), t.Name())
		} else {
			assert.NoError(t, err, t.Name())
		}
	}
}
