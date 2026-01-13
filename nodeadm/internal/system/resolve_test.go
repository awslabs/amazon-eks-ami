package system

import (
	"testing"

	"github.com/stretchr/testify/assert"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
)

func TestGenerateSystemdResolvedConfig(t *testing.T) {
	aspect := &resolveAspect{}

	tests := []struct {
		name     string
		options  api.NetworkOptions
		expected string
	}{
		{
			name: "empty config",
			options: api.NetworkOptions{
				Nameservers: []string{},
				Domains:     []string{},
			},
			expected: "[Resolve]\n\n\n",
		},
		{
			name: "nameservers only",
			options: api.NetworkOptions{
				Nameservers: []string{"8.8.8.8", "8.8.4.4"},
				Domains:     []string{},
			},
			expected: "[Resolve]\nDNS=8.8.8.8 8.8.4.4\n\n",
		},
		{
			name: "domains only",
			options: api.NetworkOptions{
				Nameservers: []string{},
				Domains:     []string{"example.com", "test.local"},
			},
			expected: "[Resolve]\n\nDomains=example.com test.local\n",
		},
		{
			name: "single nameserver",
			options: api.NetworkOptions{
				Nameservers: []string{"8.8.8.8"},
				Domains:     []string{},
			},
			expected: "[Resolve]\nDNS=8.8.8.8\n\n",
		},
		{
			name: "both nameservers and domains",
			options: api.NetworkOptions{
				Nameservers: []string{"1.1.1.1", "1.0.0.1"},
				Domains:     []string{"company.com", "internal.local"},
			},
			expected: "[Resolve]\nDNS=1.1.1.1 1.0.0.1\nDomains=company.com internal.local\n",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := aspect.generateSystemdResolvedConfig(tt.options)
			assert.NoError(t, err)
			assert.Equal(t, tt.expected, string(result))
		})
	}
}
