package util

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetEcrUri(t *testing.T) {
	tests := []struct {
		ecrUriRequest  GetEcrUriRequest
		expectedEcrUri string
	}{
		{
			ecrUriRequest: GetEcrUriRequest{
				Region:  "mars-west-1",
				Domain:  "amazonaws.com.mars",
				Account: "999999999999",
			},
			expectedEcrUri: "999999999999.dkr.ecr.mars-west-1.amazonaws.com.mars",
		},
		{
			ecrUriRequest: GetEcrUriRequest{
				Region: "us-east-2",
				Domain: "amazonaws.com",
			},
			expectedEcrUri: "602401143452.dkr.ecr.us-east-2.amazonaws.com",
		},
		{
			ecrUriRequest: GetEcrUriRequest{
				Region: "eu-south-100",
				Domain: "amazonaws.com",
			},
			expectedEcrUri: "602401143452.dkr.ecr.us-west-2.amazonaws.com",
		},
		{
			ecrUriRequest: GetEcrUriRequest{
				Region: "us-gov-east-100",
				Domain: "amazonaws.com.us-gov",
			},
			expectedEcrUri: "013241004608.dkr.ecr.us-gov-west-1.amazonaws.com.us-gov",
		},
		{
			ecrUriRequest: GetEcrUriRequest{
				Region: "cn-north-100",
				Domain: "amazonaws.com.cn",
			},
			expectedEcrUri: "961992271922.dkr.ecr.cn-northwest-1.amazonaws.com.cn",
		},
		{
			ecrUriRequest: GetEcrUriRequest{
				Region: "us-iso-west-100",
				Domain: "amazonaws.com.iso",
			},
			expectedEcrUri: "725322719131.dkr.ecr.us-iso-east-1.amazonaws.com.iso",
		},
		{
			ecrUriRequest: GetEcrUriRequest{
				Region: "us-isob-west-100",
				Domain: "amazonaws.com.isob",
			},
			expectedEcrUri: "187977181151.dkr.ecr.us-isob-east-1.amazonaws.com.isob",
		},
	}

	for _, test := range tests {
		ecrUri, err := GetEcrUri(test.ecrUriRequest)
		if err != nil {
			t.Error(err)
		}
		assert.Equal(t, test.expectedEcrUri, ecrUri)
	}
}
