package system

import (
	"testing"

	"github.com/awslabs/amazon-eks-ami/nodeadm/internal/api"
	"github.com/stretchr/testify/assert"
)

func TestValidateVolumes(t *testing.T) {
	tests := []struct {
		name    string
		volumes []api.VolumeMount
		wantErr string
	}{
		{
			name: "one volume per mount target",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/var/lib/containerd"},
				{Device: "/dev/xvdc", MountTarget: "/var/lib/kubelet"},
			},
		},
		{
			name: "one volume shared by bind targets",
			volumes: []api.VolumeMount{
				{
					Device:      "/dev/xvdb",
					MountTarget: "/mnt/k8s-disks/ebs0",
					BindTargets: []string{"/var/lib/containerd", "/var/lib/kubelet", "/var/log/pods"},
				},
			},
		},
		{
			name: "duplicate mount target",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/var/lib/containerd"},
				{Device: "/dev/xvdc", MountTarget: "/var/lib/containerd/"},
			},
			wantErr: "duplicate mount target /var/lib/containerd: configured for both /dev/xvdb and /dev/xvdc",
		},
		{
			name: "bind target is another volume's mount target",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/var/lib/containerd"},
				{Device: "/dev/xvdc", MountTarget: "/mnt/k8s-disks/ebs0", BindTargets: []string{"/var/lib/containerd"}},
			},
			wantErr: "duplicate mount target /var/lib/containerd: configured for both /dev/xvdb and /dev/xvdc",
		},
		{
			name: "bind target repeated within a volume",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/mnt/k8s-disks/ebs0", BindTargets: []string{"/var/lib/kubelet", "/var/lib/kubelet"}},
			},
			wantErr: "duplicate mount target /var/lib/kubelet: configured for both /dev/xvdb and /dev/xvdb",
		},
		{
			name: "bind targets with the same last path element",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/mnt/k8s-disks/ebs0", BindTargets: []string{"/var/lib/kubelet", "/opt/kubelet"}},
			},
			wantErr: "bind targets /var/lib/kubelet and /opt/kubelet of /dev/xvdb would share /mnt/k8s-disks/ebs0/kubelet",
		},
		{
			name: "relative bind target",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/mnt/k8s-disks/ebs0", BindTargets: []string{"var/lib/kubelet"}},
			},
			wantErr: `bind target "var/lib/kubelet" of /dev/xvdb must be an absolute path other than /`,
		},
		{
			name: "root bind target",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/mnt/k8s-disks/ebs0", BindTargets: []string{"/"}},
			},
			wantErr: `bind target "/" of /dev/xvdb must be an absolute path other than /`,
		},
		{
			name: "bind target inside its mount target",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/mnt/k8s-disks/ebs0", BindTargets: []string{"/mnt/k8s-disks/ebs0/kubelet"}},
			},
			wantErr: "bind target /mnt/k8s-disks/ebs0/kubelet of /dev/xvdb overlaps its mount target /mnt/k8s-disks/ebs0",
		},
		{
			name: "mount target inside its bind target",
			volumes: []api.VolumeMount{
				{Device: "/dev/xvdb", MountTarget: "/var/lib/kubelet/ebs", BindTargets: []string{"/var/lib/kubelet"}},
			},
			wantErr: "bind target /var/lib/kubelet of /dev/xvdb overlaps its mount target /var/lib/kubelet/ebs",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateVolumes(tt.volumes)
			if tt.wantErr == "" {
				assert.NoError(t, err)
			} else {
				assert.EqualError(t, err, tt.wantErr)
			}
		})
	}
}

func TestBindSource(t *testing.T) {
	assert.Equal(t, "/mnt/k8s-disks/ebs0/containerd", bindSource("/mnt/k8s-disks/ebs0", "/var/lib/containerd"))
	assert.Equal(t, "/mnt/k8s-disks/ebs0/pods", bindSource("/mnt/k8s-disks/ebs0/", "/var/log/pods"))
}
