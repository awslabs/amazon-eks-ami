package networkmanager

const CacheDir = "/etc/eks/nodeadm/udev-net-manager"

const (
	// in a future version of systemd (v258+?) the network manager reads udev
	// properties to tell if the interface link should be managed. by default it
	// assumes they should be, but if the 'ID_NET_MANAGED_BY' property exists
	// and its value is not equal to 'io.systemd.Network', systemd is forced to
	// stop managing the link.
	//
	// see: https://github.com/systemd/systemd/pull/29782
	// see: https://github.com/systemd/systemd/blob/9709deba913c9c2c2e9764bcded35c6081b05197/src/network/networkd-link.c#L1372-L1396
	ManagerSystemd = "io.systemd.Network"

	// NOTE: other manager names have no functional value, they only need to be
	// differentiated from the managerSystemd name.

	ManagerCNI = "cni"
)
