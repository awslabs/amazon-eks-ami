package kubelet

import (
	"bufio"
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"fmt"
	"math"
	"strings"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/stretchr/testify/assert"
)

var initialCacheContents = cachedInstanceInfoBytes

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
		vcpus               int
		memoryMiB           int64
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
			// regression: a 3-var-only expression evaluates identically with the new vars registered
			expression:      "max_pods < 110 ? max_pods : 110",
			standardMaxPods: 58,
			expectedValue:   58,
		},
		{
			// new: vcpus is usable (ternary equivalent of min(max_pods, vcpus * 10))
			expression:      "(vcpus * 10) < max_pods ? (vcpus * 10) : max_pods",
			vcpus:           2,
			standardMaxPods: 58,
			expectedValue:   20,
		},
		{
			// new: physical_memory_mib is usable
			expression:      "(physical_memory_mib / 1024) > 32 ? 110 : max_pods",
			memoryMiB:       65536,
			standardMaxPods: 58,
			expectedValue:   110,
		},
		{
			// new: physical_memory_mib comparison falls through when it doesn't match
			expression:      "(physical_memory_mib / 1024) > 32 ? 110 : max_pods",
			memoryMiB:       8192,
			standardMaxPods: 58,
			expectedValue:   58,
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
			expression:          "max_pods - 2",
			standardMaxPods:     1,
			expectErr:           true,
			expectedErrContents: fmt.Sprintf("max pods value -1 from custom expression evaluation is invalid: value must be a positive integer less than %d", math.MaxInt32),
		},
		{
			// cannot evaluate a boolean as the max pods value
			expression:          "true",
			expectErr:           true,
			expectedErrContents: "could not interpret result \"true\" from evaluation of custom max pods expression as an integer: type conversion error from 'bool' to 'int'",
		},
	}
	for _, test := range tests {
		val, err := evaluateCustomMaxPodsExpression(test.expression, util.InstanceInfo{
			InstanceType:              "fake-type1.xlarge",
			DefaultMaxENIs:            int32(test.defaultENIs),
			Ipv4AddressesPerInterface: int32(test.ipsPerENI),
			VCpus:                     int32(test.vcpus),
			PhysicalMemoryMiB:         test.memoryMiB,
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

// legacy supplemented types (addInstanceTypeSupplements) that AWS no longer returns from
// ec2:DescribeInstanceTypes and publishes no current specs for, so they carry zero vcpus/memory.
// This allowlist should only ever shrink: a new instance type with zero vcpus/memory is a bug.
var instanceTypesToleratingZeroVCpusAndMemory = map[string]bool{
	"cr1.8xlarge":   true,
	"hs1.8xlarge":   true,
	"c5a.metal":     true,
	"c5ad.metal":    true,
	"bmn-sf1.metal": true,
}

func TestInstanceInfoLoadable(t *testing.T) {
	if (len(cachedInstanceInfoBytes) == 0) || string(cachedInstanceInfoBytes) != string(initialCacheContents) {
		assert.FailNow(t, "instance info cache is missing or incorrectly set")
	}
	for s := bufio.NewScanner(bytes.NewReader(cachedInstanceInfoBytes)); s.Scan(); {
		var instanceInfo util.InstanceInfo
		if err := json.Unmarshal(s.Bytes(), &instanceInfo); err != nil {
			assert.NoError(t, err)
		}
		assert.NotEmpty(t, instanceInfo.InstanceType)
		assert.Greater(t, instanceInfo.DefaultMaxENIs, int32(0))
		assert.Greater(t, instanceInfo.Ipv4AddressesPerInterface, int32(0))
		// we expect at least 2 pods for the host networking ones
		assert.Greater(t, calculateStandardMaxPods(instanceInfo), int32(1))
		if !instanceTypesToleratingZeroVCpusAndMemory[instanceInfo.InstanceType] {
			assert.Greater(t, instanceInfo.VCpus, int32(0), "unexpected zero vcpus for %s", instanceInfo.InstanceType)
			assert.Greater(t, instanceInfo.PhysicalMemoryMiB, int64(0), "unexpected zero memory for %s", instanceInfo.InstanceType)
		}
	}
}
