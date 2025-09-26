package kubelet

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/stretchr/testify/assert"
)

var initialLen = len(cachedInstanceInfoBytes)
var initialCacheContents = cachedInstanceInfoBytes

func TestCalcMaxPods(t *testing.T) {
	var tests = []struct {
		instanceType     string
		customExpression string
		emptyCache       bool
		defaultENIs      int
		ipsPerENI        int
		expectedValue    int32
	}{
		{
			// standard happy path
			instanceType:  "fake-type1.xlarge",
			defaultENIs:   3,
			ipsPerENI:     6,
			expectedValue: 17,
		},
		{
			// standard happy path
			instanceType:  "fake-type1.8xlarge",
			defaultENIs:   6,
			ipsPerENI:     12,
			expectedValue: 68,
		},
		{
			// undiscoverable instance info, fallback to default value
			instanceType:  "fake-type1.xlarge",
			emptyCache:    true,
			defaultENIs:   3,
			ipsPerENI:     6,
			expectedValue: 110,
		},
		{
			// standard equation applied as a custom eqxpression
			instanceType:     "fake-type1.xlarge",
			customExpression: "(default_enis * (ips_per_eni - 1)) + 2",
			defaultENIs:      3,
			ipsPerENI:        6,
			expectedValue:    17,
		},
		{
			// custom expression
			instanceType:     "fake-type1.xlarge",
			customExpression: "(default_enis * (ips_per_eni - 1)) + 3",
			defaultENIs:      3,
			ipsPerENI:        6,
			expectedValue:    18,
		},
		{
			// invalid custom expression, fallback to default calculation
			instanceType:     "fake-type1.xlarge",
			customExpression: "(default_enis * (ips_per_eni - 1)) + 3 - fake_variable",
			defaultENIs:      3,
			ipsPerENI:        6,
			expectedValue:    17,
		},
		{
			// invalid custom expression and undiscoverable instance info, fallback to default value
			instanceType:     "fake-type1.xlarge",
			customExpression: "(default_enis * (ips_per_eni - 1)) + 3 - fake_variable",
			emptyCache:       true,
			defaultENIs:      3,
			ipsPerENI:        6,
			expectedValue:    110,
		},
	}
	for _, test := range tests {
		var cacheContentString string
		if !test.emptyCache {
			cacheContentString = fmt.Sprintf("{\"instanceType\":\"%s\",\"defaultNetworkCardIndex\":0,\"networkCardInfo\":[{\"networkCardIndex\":0,\"maximumNetworkInterfaces\":%d}],\"ipv4AddressesPerInterface\":%d}", test.instanceType, test.defaultENIs, test.ipsPerENI)
		}
		cachedInstanceInfoBytes = []byte(cacheContentString)
		val := CalcMaxPods("fake-region-1", test.instanceType, &test.customExpression)
		assert.Equal(t, test.expectedValue, val)
	}
	cachedInstanceInfoBytes = initialCacheContents
}

func TestEvaluateCustomMaxPodsExpression(t *testing.T) {
	var tests = []struct {
		expression          string
		defaultENIs         int
		ipsPerENI           int
		standardMaxPods     int32
		expectedValue       int32
		expectErr           bool
		expectedErrContents string
	}{
		{
			// basic integer inputs should return as themselves
			expression:    "417",
			expectedValue: 417,
		},
		{
			// standard equation should always work, mocks a t3.medium
			expression:    "(default_enis * (ips_per_eni - 1)) + 2",
			defaultENIs:   3,
			ipsPerENI:     6,
			expectedValue: 17,
		},
		{
			// emulate unbounded prefix delegation on a t3.medium
			expression:    "(default_enis * ((ips_per_eni - 1) * 16)) + 2",
			defaultENIs:   3,
			ipsPerENI:     6,
			expectedValue: 242,
		},
		{
			// emulate arbitrarily bounded prefix delegation on a t3.medium
			expression:    "((default_enis * ((ips_per_eni * 16) - 1)) + 2) < 30 ? ((default_enis * ((ips_per_eni * 16) - 1)) + 2) : 30",
			defaultENIs:   3,
			ipsPerENI:     6,
			expectedValue: 30,
		},
		{
			// emulate custom networking on a t3.medium
			expression:    "((default_enis - 1) * (ips_per_eni - 1)) + 2",
			defaultENIs:   3,
			ipsPerENI:     6,
			expectedValue: 12,
		},
		{
			// max_pods should return max_pods
			expression:      "max_pods",
			standardMaxPods: 7,
			expectedValue:   7,
		},
		{
			// max_pods can be offset
			expression:      "max_pods + 2",
			defaultENIs:     999,
			ipsPerENI:       9999,
			standardMaxPods: 7,
			expectedValue:   9,
		},
		{
			// false variable references should error
			expression:          "default_enis + fake_variable",
			expectErr:           true,
			expectedErrContents: "failed to compile custom max pods expression",
		},
		{
			// expression does not allow overflow
			expression:          "default_enis * 2",
			defaultENIs:         math.MaxInt32,
			expectErr:           true,
			expectedErrContents: "max pods value from custom expression is too large",
		},
		{
			// cannot cast a boolean to int
			expression:          "true",
			expectErr:           true,
			expectedErrContents: "could not cast",
		},
	}
	for _, test := range tests {
		val, err := evaluateCustomMaxPodsExpression(test.expression, util.InstanceInfo{
			InstanceType:            "fake-type1.xlarge",
			DefaultNetworkCardIndex: 0,
			NetworkCards: []util.NetworkCardInfo{
				{
					NetworkCardIndex:         0,
					MaximumNetworkInterfaces: int32(test.defaultENIs),
				},
			},
			Ipv4AddressesPerInterface: int32(test.ipsPerENI),
		}, test.standardMaxPods)
		if test.expectErr {
			assert.Error(t, err)
			assert.ErrorContains(t, err, test.expectedErrContents)
		} else {
			assert.NoError(t, err)
			assert.Equal(t, test.expectedValue, val)
		}
	}
}

func TestGetInstanceInfo(t *testing.T) {
	var tests = []struct {
		instanceType            string
		cacheContentString      string
		expectedInfo            util.InstanceInfo
		expectErr               bool
		expectedErrContents     string
		unexpectedErrorContents string
	}{
		{
			// happy path, instance exists at the beginning of the cache
			instanceType: "fake-type1.xlarge",
			cacheContentString: `{"instanceType":"fake-type1.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":1}],"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":99}],"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":3}],"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:            "fake-type1.xlarge",
				DefaultNetworkCardIndex: 0,
				NetworkCards: []util.NetworkCardInfo{
					{
						NetworkCardIndex:         0,
						MaximumNetworkInterfaces: 1,
					},
				},
				Ipv4AddressesPerInterface: 1,
			},
		},
		{
			// happy path, instance exists in middle of cache
			instanceType: "fake-type2.xlarge",
			cacheContentString: `{"instanceType":"fake-type1.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":1}],"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":99}],"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":3}],"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:            "fake-type2.xlarge",
				DefaultNetworkCardIndex: 0,
				NetworkCards: []util.NetworkCardInfo{
					{
						NetworkCardIndex:         0,
						MaximumNetworkInterfaces: 99,
					},
				},
				Ipv4AddressesPerInterface: 99,
			},
		},
		{
			// happy path, instance exists at the end of the cache
			instanceType: "fake-type3.xlarge",
			cacheContentString: `{"instanceType":"fake-type1.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":1}],"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":99}],"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":3}],"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:            "fake-type3.xlarge",
				DefaultNetworkCardIndex: 0,
				NetworkCards: []util.NetworkCardInfo{
					{
						NetworkCardIndex:         0,
						MaximumNetworkInterfaces: 3,
					},
				},
				Ipv4AddressesPerInterface: 10,
			},
		},
		{
			// cache empty and instance info is undiscoverable
			instanceType:        "fake-type1.xlarge",
			expectErr:           true,
			expectedErrContents: "operation error EC2: DescribeInstanceTypes",
		},
		{
			// cache is not empty but instance info is undiscoverable
			instanceType: "fake-type1.xlarge",
			cacheContentString: `{"instanceType":"fake-type2.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":1}],"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type3.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":99}],"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type4.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":3}],"ipv4AddressesPerInterface":10}`,
			expectErr:           true,
			expectedErrContents: "operation error EC2: DescribeInstanceTypes",
		},
		{
			// line with the instance type is corrupted
			instanceType: "fake-type1.xlarge",
			cacheContentString: `{"instanceType":fake-type1.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":1}],"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":99}],"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":3}],"ipv4AddressesPerInterface":10}`,
			expectErr:           true,
			expectedErrContents: "operation error EC2: DescribeInstanceTypes",
		},
		{
			// line before the one with the instance type is corrupted
			instanceType: "fake-type3.xlarge",
			cacheContentString: `{"instanceType":fake-type1.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":1}],"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":99}],"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultNetworkCardIndex":0,"networkCardInfo":[{"networkCardIndex":0,"maximumNetworkInterfaces":3}],"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:            "fake-type3.xlarge",
				DefaultNetworkCardIndex: 0,
				NetworkCards: []util.NetworkCardInfo{
					{
						NetworkCardIndex:         0,
						MaximumNetworkInterfaces: 3,
					},
				},
				Ipv4AddressesPerInterface: 10,
			},
		},
	}
	for _, test := range tests {
		cachedInstanceInfoBytes = []byte(test.cacheContentString)
		// use a fake region to force a consistent EC2 API call failure mode regardless of environment
		info, err := GetInstanceInfo(context.Background(), "fake-region-1", test.instanceType)
		if test.expectErr {
			assert.Error(t, err)
			assert.ErrorContains(t, err, test.expectedErrContents)
			if test.unexpectedErrorContents != "" && strings.Contains(err.Error(), test.unexpectedErrorContents) {
				t.Fatalf("error message %q contains %q when it was not expected", err.Error(), test.unexpectedErrorContents)
			}
		} else {
			assert.NoError(t, err)
			assert.Equal(t, test.expectedInfo, info)
		}
	}
	cachedInstanceInfoBytes = initialCacheContents
}

// validate contents of instance info cache to add an easy safety net for each future change
// this test should be ran last to ensure that overwriting of the cache in prior steps does not persist
func TestInstanceInfoLoadable(t *testing.T) {
	if len(cachedInstanceInfoBytes) != initialLen || (len(cachedInstanceInfoBytes) == 0) {
		assert.FailNow(t, "instance info cache is missing")
	}
	cachedInfoReader := bytes.NewReader(cachedInstanceInfoBytes)
	s := bufio.NewScanner(cachedInfoReader)
	for s.Scan() {
		var instanceInfo util.InstanceInfo
		if err := json.Unmarshal(s.Bytes(), &instanceInfo); err != nil {
			assert.NoError(t, err)
		}
		if len(instanceInfo.InstanceType) == 0 {
			assert.Fail(t, "line with missing instance type name found in instance info cache")
		}
		if instanceInfo.DefaultNetworkCardIndex < 0 {
			assert.Failf(t, "negative value found as the default network card index for instance type %s: %d", instanceInfo.InstanceType, instanceInfo.DefaultNetworkCardIndex)
		}
		if len(instanceInfo.NetworkCards) == 0 {
			assert.Failf(t, "instance %q missing network cards in instance info cache", instanceInfo.InstanceType)
		}
		var foundDefaultNetworkCard bool
		for _, networkCard := range instanceInfo.NetworkCards {
			if networkCard.NetworkCardIndex < 0 {
				assert.Failf(t, "instance %s has a network card with a negative index: %d", instanceInfo.InstanceType, networkCard.NetworkCardIndex)
			}
			if instanceInfo.DefaultNetworkCardIndex == networkCard.NetworkCardIndex {
				foundDefaultNetworkCard = true
			}
			if networkCard.MaximumNetworkInterfaces <= 0 {
				assert.Failf(t, "instance %s has a network card at index %d with a non-positive number of interfaces", instanceInfo.InstanceType, networkCard.MaximumNetworkInterfaces)
			}
		}
		if !foundDefaultNetworkCard {
			assert.Failf(t, "instance %s is missing its default network card at index %d", instanceInfo.InstanceType, instanceInfo.DefaultNetworkCardIndex)
		}
	}
}
