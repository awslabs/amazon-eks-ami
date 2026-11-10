package system

// markerPath is created by kubelet.service (ExecStartPre) every time kubelet starts.
// Interfaces attached after it exists may be owned by the CNI.
// Keep in sync with templates/*/runtime/rootfs/etc/systemd/system/kubelet.service.
const markerPath = "/run/eks/kubelet/started"

func MarkerPath() string {
	return markerPath
}
