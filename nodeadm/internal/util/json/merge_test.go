package json

import (
	"encoding/json"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestMergeStructs(t *testing.T) {
	type testStruct struct {
		Foo string `json:"foo,omitempty"`
	}

	testCases := []struct {
		base     testStruct
		patch    testStruct
		expected testStruct
	}{
		{
			base:     testStruct{Foo: "bar"},
			patch:    testStruct{Foo: "baz"},
			expected: testStruct{Foo: "baz"},
		},
		{
			base:     testStruct{Foo: "bar"},
			patch:    testStruct{},
			expected: testStruct{Foo: "bar"},
		},
		{
			base:     testStruct{},
			patch:    testStruct{Foo: "bar"},
			expected: testStruct{Foo: "bar"},
		},
	}

	for _, testCase := range testCases {
		baseBytes, err := json.Marshal(testCase.base)
		if err != nil {
			t.Fatal(err)
		}

		inBytes, err := json.Marshal(testCase.patch)
		if err != nil {
			t.Fatal(err)
		}

		merged, err := Merge(string(baseBytes), string(inBytes))
		if err != nil {
			t.Fatal(err)
		}

		actual := testStruct{}
		if err := json.Unmarshal([]byte(*merged), &actual); err != nil {
			t.Fatal(err)
		}

		assert.Equal(t, testCase.expected, actual)
	}
}

// Ensure that output is formatted in a readable way
func TestFormatting(t *testing.T) {
	base := `{ "foo": "bar" }`
	merged, err := Merge(base, "{}")
	if err != nil {
		t.Fatal(err)
	}
	expected := `{
    "foo": "bar"
}`
	assert.Equal(t, expected, *merged)
}
