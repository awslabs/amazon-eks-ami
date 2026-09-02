# nodeadm

Initializes a node in an EKS cluster.

---

## Usage

To initialize a node:
```
nodeadm init
```

> **Note**
> This happens automatically, via a `systemd` service, on AL2023-based EKS AMI's.

---

## Configuration

`nodeadm` uses a YAML configuration schema that will look familiar to Kubernetes users.

This is an example of the minimum required parameters:
```yaml
---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec:
  cluster:
    name: my-cluster
    apiServerEndpoint: https://example.com
    certificateAuthority: Y2VydGlmaWNhdGVBdXRob3JpdHk=
    cidr: 10.100.0.0/16
```

You'll typically provide this configuration in your EC2 instance's user data, either as-is or embedded within a MIME multi-part document:
```
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="BOUNDARY"

--BOUNDARY
Content-Type: application/node.eks.aws

---
apiVersion: node.eks.aws/v1alpha1
kind: NodeConfig
spec: ...

--BOUNDARY--
```

The source for the configuration object can be specified with the `--config-source` flag and follows a URI format. The default is `imds://user-data`, which pulls from EC2 instance userdata, but you may provide a file path with `file://...`.

The `nodeadm-run.service` systemd unit is configured with two config sources: `imds://user-data` and `file:///etc/eks/nodeadm.d/`. Any `NodeConfig` files (`.yaml`, `.yml`, or `.json`) placed under `/etc/eks/nodeadm.d/` will be merged with the config supplied via user data, and take precedence over it. See the [examples](doc/examples.md#overriding-configuration-with-drop-in-files) for details.

The [API reference documentation](doc/api.md) contains the details of the configuration types.
