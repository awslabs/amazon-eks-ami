package util

import (
	"math"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestExtractPercentagePointsFromPortion(t *testing.T) {
	testCases := []struct {
		portionSize uint64
		numerator   int
		denominator int
		expected    float64
	}{
		{
			portionSize: 30,
			numerator:   10,
			denominator: 100,
			expected:    3,
		},
		{
			portionSize: 100,
			numerator:   30,
			denominator: 1000,
			expected:    3,
		},
		{
			portionSize: math.MaxInt,
			numerator:   0,
			denominator: math.MaxInt,
			expected:    0,
		},
		{
			portionSize: math.MaxInt,
			numerator:   100,
			denominator: 100,
			expected:    math.MaxInt,
		},
		{
			portionSize: math.MaxInt,
			numerator:   math.MaxInt / 2,
			denominator: math.MaxInt,
			expected:    math.MaxInt / 2,
		},
	}
	for _, testCase := range testCases {
		output := ExtractRatioFromPortion(testCase.portionSize, testCase.numerator, testCase.denominator)
		assert.Equal(t, testCase.expected, output)
	}
}

// Tests to ensure no rounding errors, up to the guaranteed precision
func TestExtractPercentagePointsFromPortionNoRound(t *testing.T) {
	testCases := []struct {
		portionSize       uint64
		secondPortionSize uint64
		numerator         int
		denominator       int
	}{
		{
			// expect full precision
			portionSize:       uint64(math.Pow(2, 52)),
			secondPortionSize: uint64(math.Pow(2, 52) + 1),
			numerator:         1,
			denominator:       2,
		},
		{
			// expect accuracy on multiples of 2
			portionSize:       uint64(math.Pow(2, 53)),
			secondPortionSize: uint64(math.Pow(2, 53) + 2),
			numerator:         1,
			denominator:       2,
		},
		{
			// expect accuracy on multiples of 4
			portionSize:       uint64(math.Pow(2, 54)),
			secondPortionSize: uint64(math.Pow(2, 54) + 3),
			numerator:         1,
			denominator:       2,
		},
		{
			// expect accuracy on multiples of 2048 (2^(n - 52)), n=63
			portionSize:       uint64(math.Pow(2, 64)),
			secondPortionSize: uint64(math.Pow(2, 64) - 2048),
			numerator:         1,
			denominator:       2,
		},
	}
	for _, testCase := range testCases {
		output := ExtractRatioFromPortion(testCase.portionSize, testCase.numerator, testCase.denominator)
		secondOutput := ExtractRatioFromPortion(testCase.secondPortionSize, testCase.numerator, testCase.denominator)
		assert.NotEqual(t, output, secondOutput)
	}
}

func TestGetAmountFromPercentageBands(t *testing.T) {
	testCases := []struct {
		numeratorsPerRange []int
		bounds             []int
		total              uint64
		denominator        int
		expected           uint64
	}{
		{
			numeratorsPerRange: []int{30},
			bounds:             []int{0, 1000},
			total:              math.MaxInt,
			denominator:        100,
			expected:           300,
		},
		{
			numeratorsPerRange: []int{100, 50},
			bounds:             []int{0, 1000, 5000},
			total:              math.MaxInt,
			denominator:        100,
			expected:           3000,
		},
		{
			numeratorsPerRange: []int{100},
			bounds:             []int{0, math.MaxInt},
			total:              5000,
			denominator:        100,
			expected:           5000,
		},
		{
			numeratorsPerRange: []int{int(math.Pow(2, 63) / 2)},
			bounds:             []int{0, math.MaxInt},
			total:              math.MaxInt,
			denominator:        math.MaxInt,
			expected:           uint64(math.Pow(2, 63) / 2),
		},
		{
			numeratorsPerRange: []int{int(math.Pow(2, 61)), int(math.Pow(2, 61))},
			bounds:             []int{0, int(math.Pow(2, 61)), math.MaxInt},
			total:              uint64(math.Pow(2, 62)),
			denominator:        int(math.Pow(2, 62)),
			expected:           uint64(math.Pow(2, 61)),
		},
	}
	for _, testCase := range testCases {
		output := GetAmountFromPercentageBands(testCase.numeratorsPerRange, testCase.bounds, testCase.total, testCase.denominator)
		assert.Equal(t, testCase.expected, output)
	}
}
