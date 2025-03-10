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
	validTwoNetworkInterfaceDetails = []NetworkInterfaceDetails{
		{MAC: "06:83:e7:fe:fe:fe", IpV4Address: "1.2.3.4", NetworkCard: 1, DeviceNumber: 1},
		{MAC: "06:83:e7:ff:ff:ff", IpV4Address: "5.6.7.8", NetworkCard: 0, DeviceNumber: 0},
	}

	validOneNetworkInterfaceDetails = []NetworkInterfaceDetails{
		{MAC: "06:83:e7:fb:fb:fb", IpV4Address: "1.2.3.4", NetworkCard: 0, DeviceNumber: 0},
	}
	errImds404     = errors.New("http response error StatusCode: 404, request to EC2 IMDS failed")
	errImdsGeneric = errors.New("IMDS error")
)

func mockGetPropertyImdsError(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	switch prop {
	case "network/interfaces/macs/":
		return "", errImdsGeneric
	}
	return "", nil
}

func mockGetPropertyNonMulticardInstance(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	switch prop {
	case "network/interfaces/macs/06:83:e7:fd:fd:fd/":
		return "06:83:e7:fd:fd:fd", nil
	case "network/interfaces/macs/":
		return nonMulticardInstanceMac, nil
	case "network/interfaces/macs/06:83:e7:fd:fd:fd/network-card":
		return "", errImds404
	}
	return "", nil
}

func mockGetPropertyTwoValidCards(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	switch prop {
	case "network/interfaces/macs/":
		return validNetworkInterfacesMacs, nil
	case "network/interfaces/macs/06:83:e7:fe:fe:fe/mac":
		return "06:83:e7:fe:fe:fe", nil
	case "network/interfaces/macs/06:83:e7:ff:ff:ff/mac":
		return "06:83:e7:ff:ff:ff", nil
	case "network/interfaces/macs/06:83:e7:fe:fe:fe/network-card":
		return "1", nil
	case "network/interfaces/macs/06:83:e7:fe:fe:fe/device-number":
		return "1", nil
	case "network/interfaces/macs/06:83:e7:ff:ff:ff/network-card":
		return "0", nil
	case "network/interfaces/macs/06:83:e7:ff:ff:ff/device-number":
		return "0", nil
	case "network/interfaces/macs/06:83:e7:fe:fe:fe/local-ipv4s":
		return "1.2.3.4", nil
	case "network/interfaces/macs/06:83:e7:ff:ff:ff/local-ipv4s":
		return "5.6.7.8", nil
	}

	return "", nil
}

func mockGetPropertyNoIp(ctx context.Context, prop imds.IMDSProperty) (string, error) {
	switch prop {
	case "network/interfaces/macs/06:83:e7:fb:fb:fb/mac":
		return "06:83:e7:fb:fb:fb", nil
	case "network/interfaces/macs/":
		return multicardNoIpOnOneCard, nil
	case "network/interfaces/macs/06:83:e7:fb:fb:fb/network-card":
		return "0", nil
	case "network/interfaces/macs/06:83:e7:fb:fb:fb/device-number":
		return "0", nil
	case "network/interfaces/macs/06:83:e7:fc:fc:fc/network-card":
		return "1", nil
	case "network/interfaces/macs/06:83:e7:fc:fc:fc/device-number":
		return "1", nil
	case "network/interfaces/macs/06:83:e7:fc:fc:fd/network-card":
		return "2", nil
	case "network/interfaces/macs/06:83:e7:fc:fc:fd/device-number":
		return "2", nil
	case "network/interfaces/macs/06:83:e7:fb:fb:fb/local-ipv4s":
		return "1.2.3.4", nil
	case "network/interfaces/macs/06:83:e7:fc:fc:fc/local-ipv4s":
		return "", errImds404
	case "network/interfaces/macs/06:83:e7:fc:fc:fd/local-ipv4s":
		return "", nil
	}
	return "", nil
}

func TestGetNetworkInterfaceDetails(t *testing.T) {

	tests := []struct {
		name                            string
		mockGetProperty                 func(ctx context.Context, prop imds.IMDSProperty) (string, error)
		expectedNetworkInterfaceDetails []NetworkInterfaceDetails
		expectedError                   error
	}{
		{
			name:                            "Success card 0 and card 1 available",
			mockGetProperty:                 mockGetPropertyTwoValidCards,
			expectedNetworkInterfaceDetails: validTwoNetworkInterfaceDetails,
			expectedError:                   nil,
		},
		{
			name:                            "Success non multicard instance",
			mockGetProperty:                 mockGetPropertyNonMulticardInstance,
			expectedNetworkInterfaceDetails: nil,
			expectedError:                   nil,
		},
		{
			name:                            "Success multicard instance no IP",
			mockGetProperty:                 mockGetPropertyNoIp,
			expectedNetworkInterfaceDetails: validOneNetworkInterfaceDetails,
			expectedError:                   nil,
		},
		{
			name:                            "Fail with IMDS error",
			mockGetProperty:                 mockGetPropertyImdsError,
			expectedNetworkInterfaceDetails: nil,
			expectedError:                   errors.New("failed to get network interfaces from imds: IMDS error"),
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Logf("Running test: %s", test.name)
			ctx := context.Background()
			fakeImds := imds.FakeIMDSClient{
				GetPropertyFunc: test.mockGetProperty,
			}
			actualDetails, err := getNetworkInterfaceDetails(ctx, &fakeImds)

			assert.Equal(t, test.expectedNetworkInterfaceDetails, actualDetails, t.Name())
			if test.expectedError != nil {
				assert.EqualError(t, err, test.expectedError.Error(), t.Name())
			} else {
				assert.NoError(t, err, t.Name())
			}
		})
	}
}
