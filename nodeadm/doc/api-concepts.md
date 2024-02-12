# API Concepts

## Versioning

The API types for `nodeadm` (the `node.eks.aws` API group) are versioned in a similar manner to the [Kubernetes API](https://kubernetes.io/docs/reference/using-api/#api-versioning).

There are three levels of stability and support:

### Alpha
- Example: `v1alpha2.`
- The software may contain bugs.
- Support for an alpha API may be removed at any time.
- Subsequent alpha API versions may include incompatible changes, and migration instructions may not be provided.

### Beta
- Example: `v3beta4`.
- The software is well-tested, and production use is considered safe.
- Support for a beta API will remain for at least one release following deprecation. That is, support for two successive beta API versions will overlap by at least one release.
- Features will not be dropped, though the details may change.
- Subsequent beta or stable API versions may include incompatible changes, and migration instructions will be provided.

### Stable
- Example: `v5`
- Support for a stable API will remain at least until the release of the next major version of Amazon Linux.