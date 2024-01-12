package toml

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/util"
	"github.com/stretchr/testify/assert"
)

func TestMerge(t *testing.T) {
	a := `[foo]
		bar = 'baz'
	`
	b := `[foo]
		baz = 'bar'
	`
	expected := `[foo]
		bar = 'baz'
		baz = 'bar'
		`
	merged, err := Merge(util.Dedent(a), util.Dedent(b))
	if err != nil {
		t.Fatal(err)
	}
	assert.Equal(t, util.Dedent(expected), *merged)
}
