package v1alpha1

// ENITagSystemManaged set to "true" on an ENI makes nodeadm configure it via
// systemd-networkd when the ENITags feature gate is enabled.
const ENITagSystemManaged = "alpha.node.eks.aws/system_managed"
