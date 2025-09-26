package kubelet

import (
	"bufio"
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"strings"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/stretchr/testify/assert"
)

//go:embed eni-max-pods.txt
var eniMaxPods string

var maxPodsPerInstanceType map[string]int

var initialCacheContents []byte

func init() {
	maxPodsPerInstanceType = make(map[string]int)
	lines := strings.Split(eniMaxPods, "\n")

	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.Fields(line)
		if len(parts) != 2 {
			continue
		}

		instanceType := parts[0]
		maxPods, err := strconv.Atoi(parts[1])
		if err != nil {
			continue
		}

		maxPodsPerInstanceType[instanceType] = maxPods
	}

	// init blocks run after package-level variables evaluation, set
	// here to make sure the embedding is evaluated first
	initialCacheContents = cachedInstanceInfoBytes
}

func TestCalcMaxPods(t *testing.T) {
	var tests = []struct {
		customExpression string
		defaultENIs      int
		ipsPerENI        int
		expectedValue    int32
	}{
		{
			// standard happy path
			defaultENIs:   3,
			ipsPerENI:     6,
			expectedValue: 17,
		},
		{
			// standard happy path 2
			defaultENIs:   6,
			ipsPerENI:     12,
			expectedValue: 68,
		},
		{
			// standard equation applied as a custom expression
			customExpression: "(default_enis * (ips_per_eni - 1)) + 2",
			defaultENIs:      3,
			ipsPerENI:        6,
			expectedValue:    17,
		},
		{
			// valid custom expression
			customExpression: "(default_enis * (ips_per_eni - 1)) + 3",
			defaultENIs:      3,
			ipsPerENI:        6,
			expectedValue:    18,
		},
		{
			// invalid custom expression, should return standard value
			customExpression: "99 - fake_variable",
			defaultENIs:      3,
			ipsPerENI:        6,
			expectedValue:    17,
		},
	}
	for _, test := range tests {
		instanceInfo := util.InstanceInfo{
			InstanceType:              "fake-type1.xlarge",
			DefaultMaxENIs:            int32(test.defaultENIs),
			Ipv4AddressesPerInterface: int32(test.ipsPerENI),
		}
		val := CalcMaxPods(instanceInfo, test.customExpression)
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
			// ternary operator should work for setting limits
			expression:      "max_pods < 30 ? max_pods : 30",
			standardMaxPods: 35,
			expectedValue:   30,
		},
		{
			// max_pods should return standard max pods value
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
			expectedErrContents: fmt.Sprintf("value must be a positive integer less than %d", math.MaxInt32),
		},
		{
			// expression cannot evaluate as a zero value, reflexivity of standard equation
			expression:          "max_pods - ((default_enis * (ips_per_eni - 1)) + 2)",
			defaultENIs:         3,
			ipsPerENI:           6,
			standardMaxPods:     17,
			expectErr:           true,
			expectedErrContents: fmt.Sprintf("max pods value 0 from custom expression evaluation is invalid: value must be a positive integer less than %d", math.MaxInt32),
		},
		{
			// expression cannot evaluate as negative
			expression:          "- max_pods",
			standardMaxPods:     17,
			expectErr:           true,
			expectedErrContents: fmt.Sprintf("max pods value -17 from custom expression evaluation is invalid: value must be a positive integer less than %d", math.MaxInt32),
		},
		{
			// cannot evaluate a boolean as the max pods value
			expression:          "true",
			expectErr:           true,
			expectedErrContents: "could not interpret result",
		},
	}
	for _, test := range tests {
		val, err := evaluateCustomMaxPodsExpression(test.expression, util.InstanceInfo{
			InstanceType:              "fake-type1.xlarge",
			DefaultMaxENIs:            int32(test.defaultENIs),
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
			cacheContentString: `{"instanceType":"fake-type1.xlarge","defaultMaxENIs":1,"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultMaxENIs":99,"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultMaxENIs":3,"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:              "fake-type1.xlarge",
				DefaultMaxENIs:            1,
				Ipv4AddressesPerInterface: 1,
			},
		},
		{
			// happy path, instance exists in middle of cache
			instanceType: "fake-type2.xlarge",
			cacheContentString: `{"instanceType":fake-type1.xlarge","defaultMaxENIs":1,"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultMaxENIs":99,"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultMaxENIs":3,"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:              "fake-type2.xlarge",
				DefaultMaxENIs:            99,
				Ipv4AddressesPerInterface: 99,
			},
		},
		{
			// happy path, instance exists at the end of the cache
			instanceType: "fake-type3.xlarge",
			cacheContentString: `{"instanceType":fake-type1.xlarge","defaultMaxENIs":1,"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultMaxENIs":99,"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultMaxENIs":3,"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:              "fake-type3.xlarge",
				DefaultMaxENIs:            3,
				Ipv4AddressesPerInterface: 10,
			},
		},
		{
			// cache empty and instance info is undiscoverable
			instanceType:        "fake-type1.xlarge",
			cacheContentString:  "",
			expectErr:           true,
			expectedErrContents: "operation error EC2: DescribeInstanceTypes",
		},
		{
			// cache is not empty but instance info is undiscoverable
			instanceType: "fake-type4.xlarge",
			cacheContentString: `{"instanceType":"fake-type1.xlarge","defaultMaxENIs":1,"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultMaxENIs":99,"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultMaxENIs":3,"ipv4AddressesPerInterface":10}`,
			expectErr:           true,
			expectedErrContents: "operation error EC2: DescribeInstanceTypes",
		},
		{
			// line with the instance type is corrupted
			instanceType: "fake-type1.xlarge",
			cacheContentString: `{"instanceType":fake-type1.xlarge","defaultMaxENIs":1,"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultMaxENIs":99,"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultMaxENIs":3,"ipv4AddressesPerInterface":10}`,
			expectErr:           true,
			expectedErrContents: "operation error EC2: DescribeInstanceTypes",
		},
		{
			// line before the one with the instance type is corrupted
			instanceType: "fake-type3.xlarge",
			cacheContentString: `{"instanceType":fake-type1.xlarge","defaultMaxENIs":1,"ipv4AddressesPerInterface":1}
			{"instanceType":"fake-type2.xlarge","defaultMaxENIs":99,"ipv4AddressesPerInterface":99}
			{"instanceType":"fake-type3.xlarge","defaultMaxENIs":3,"ipv4AddressesPerInterface":10}`,
			expectedInfo: util.InstanceInfo{
				InstanceType:              "fake-type3.xlarge",
				DefaultMaxENIs:            3,
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

func TestInstanceInfoLoadable(t *testing.T) {
	if (len(cachedInstanceInfoBytes) == 0) || string(cachedInstanceInfoBytes) != string(initialCacheContents) {
		assert.FailNow(t, "instance info cache is missing or incorrectly set")
	}
	jsonlMaxPodsMap := make(map[string]int32)
	cachedInfoReader := bytes.NewReader(cachedInstanceInfoBytes)
	s := bufio.NewScanner(cachedInfoReader)
	for s.Scan() {
		var instanceInfo util.InstanceInfo
		if err := json.Unmarshal(s.Bytes(), &instanceInfo); err != nil {
			assert.NoError(t, err)
		}
		assert.NotEmpty(t, instanceInfo.InstanceType)
		assert.Greater(t, instanceInfo.DefaultMaxENIs, int32(0))
		assert.Greater(t, instanceInfo.Ipv4AddressesPerInterface, int32(0))
		jsonlMaxPodsMap[instanceInfo.InstanceType] = calculateStandardMaxPods(instanceInfo)
	}
	// confirm that all instances from the original max pods list have the same value
	for instanceType, classicValue := range maxPodsPerInstanceType {
		if newValue, ok := jsonlMaxPodsMap[instanceType]; !ok {
			t.Errorf("instance type %s is missing from new mapping", instanceType)
		} else if newValue != int32(classicValue) {
			t.Errorf("instance type %s should have value %d, got %d", instanceType, classicValue, newValue)
		}
	}
}
