package maxpods

import (
	"math"
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/stretchr/testify/assert"
)

func TestMaxPodsFromMemoryRoundTrip(t *testing.T) {
	testCases := []struct {
		reservableValueMiB int32
		expectedValue      int32
	}{
		{
			reservableValueMiB: 0,
			expectedValue:      255, // we always reserve at least 255 regardless of max pods
		},
		{
			reservableValueMiB: 299,
			expectedValue:      299,
		},
		{
			reservableValueMiB: 2147483647, // max int32 value (i.e. 2^31 - 1)
			expectedValue:      2147483637, // can only use up to the last multiple of 11
		},
	}
	for _, testCase := range testCases {
		maxPods := projectMaxPodsFromMemoryMiBReserved(testCase.reservableValueMiB)
		actualReservableValue := GetMemoryMebibytesToReserve(maxPods)
		assert.Equal(t, testCase.expectedValue, actualReservableValue)
	}
}

func TestMaxPodsFromENIInfo(t *testing.T) {
	testCases := []struct {
		eniInfo  util.EniInfo
		expected int32
	}{
		{
			// always allow 2 pods w/o needing any IPs
			eniInfo:  util.EniInfo{},
			expected: 2,
		},
		{
			eniInfo: util.EniInfo{
				EniCount:        2,
				PodsPerEniCount: 5,
			},
			expected: 10,
		},
		{
			// can only use secondary IPs for pods  (i.e. 2...n)
			eniInfo: util.EniInfo{
				EniCount:        50,
				PodsPerEniCount: 1,
			},
			expected: 2,
		},
	}
	for _, testCase := range testCases {
		maxPods := getMaxPodsFromENIInfo(testCase.eniInfo)
		assert.Equal(t, testCase.expected, maxPods)
	}
}

func Test_getMaxMemoryMiBToReserve(t *testing.T) {
	testCases := []struct {
		availableMemory          uint64
		expectedMemoryReservable int32
	}{
		{
			availableMemory:          0,
			expectedMemoryReservable: 0,
		},
		{
			availableMemory:          255,
			expectedMemoryReservable: 255, // 255* 1 (100%)
		},
		{
			availableMemory:          4096,
			expectedMemoryReservable: 1215, // 255 + 0.25*3,841
		},
		{
			availableMemory:          8192,
			expectedMemoryReservable: 2034, // 1215 + 0.20*4096
		},
		{
			availableMemory:          16384,
			expectedMemoryReservable: 2853, // 2034 + 0.10*8192
		},
		{
			availableMemory:          131072,
			expectedMemoryReservable: 9734, // 2853 + 0.06*114688
		},
		{
			availableMemory:          73728, // in the middle of a band
			expectedMemoryReservable: 6294,  // 2853.65 + 0.06*57344
		},
	}
	for _, testCase := range testCases {
		reservableMemory := getMaxMemoryMiBToReserve(testCase.availableMemory)
		assert.Equal(t, testCase.expectedMemoryReservable, reservableMemory)
	}
}

func TestGetMaxPodsLimitForMemoryMiB(t *testing.T) {
	testCases := []struct {
		reserverableMemoryMiB uint64
		expectedMaxPodsLimit  int32
	}{
		{
			reserverableMemoryMiB: 256,
			expectedMaxPodsLimit:  0,
		},
		{
			reserverableMemoryMiB: 512,
			expectedMaxPodsLimit:  5,
		},
		{
			reserverableMemoryMiB: math.MaxInt32,
			expectedMaxPodsLimit:  861, // effective ceiling
		},
	}
	for _, testCase := range testCases {
		maxPods := GetMaxPodsLimitForMemoryMiB(testCase.reserverableMemoryMiB)
		assert.Equal(t, testCase.expectedMaxPodsLimit, maxPods)
	}
}
