package kubelet

import (
	_ "embed"
	"strconv"
	"strings"
)

//go:embed eni-max-pods.txt
var eniMaxPods string

var MaxPodsPerInstanceType map[string]int

func init() {
	MaxPodsPerInstanceType = make(map[string]int)
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

		MaxPodsPerInstanceType[instanceType] = maxPods
	}
}
