package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testCases = []struct {
	name     string
	input    string
	expected string
}{
	{"lower", "enxaabbccddeeff", "aa:bb:cc:dd:ee:ff"},
	{"upper", "enxAABBCCDDEEFF", "aa:bb:cc:dd:ee:ff"},
	{"allNumbers", "enx001122334455", "00:11:22:33:44:55"},
}

func Test_parseIdNetNameMac(t *testing.T) {
	for _, testCase := range testCases {
		t.Run(testCase.name, func(t *testing.T) {
			actual, err := parseIdNetNameMac(testCase.input)
			if err != nil {
				t.Error(err)
			} else {
				assert.Equal(t, testCase.expected, actual)
			}
		})
	}

}

func BenchmarkParseIdNetNameMac(b *testing.B) {
	for _, testCase := range testCases {
		b.Run(testCase.name, func(b *testing.B) {
			for i := 0; i < b.N; i++ {
				parseIdNetNameMac(testCase.input)
			}
		})
	}
}
