package api

import "testing"

func TestUseInstanceIdNodeName(t *testing.T) {
	tests := []struct {
		name     string
		gates    map[Feature]bool
		osDistro OSDistro
		want     bool
	}{
		{
			name:     "al2027 defaults to instance-id when gate unset",
			gates:    nil,
			osDistro: OSDistroAL2027,
			want:     true,
		},
		{
			name:     "al2023 defaults to private-dns-name when gate unset",
			gates:    nil,
			osDistro: OSDistroAL2023,
			want:     false,
		},
		{
			name:     "explicit on wins on al2023",
			gates:    map[Feature]bool{InstanceIdNodeName: true},
			osDistro: OSDistroAL2023,
			want:     true,
		},
		{
			name:     "explicit off wins on al2027",
			gates:    map[Feature]bool{InstanceIdNodeName: false},
			osDistro: OSDistroAL2027,
			want:     false,
		},
		{
			name:     "unknown os defaults off when gate unset",
			gates:    nil,
			osDistro: OSDistro(""),
			want:     false,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := UseInstanceIdNodeName(tt.gates, tt.osDistro); got != tt.want {
				t.Errorf("UseInstanceIdNodeName(%v, %q) = %v, want %v", tt.gates, tt.osDistro, got, tt.want)
			}
		})
	}
}
