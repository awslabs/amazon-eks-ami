---
name: Bug Report
about: Report a bug encountered using the EKS AMI

---

<!-- Please use this template while reporting a bug and provide as much info as possible. Please also search for existing open and closed issues that may answer your question. Thanks!-->

**What happened**:

**What you expected to happen**:

**How to reproduce it (as minimally and precisely as possible)**:

**Anything else we need to know?**:

**Environment**:
- AWS Region:
- Instance Type(s):
- EKS Platform version (use `aws eks describe-cluster --name <name> --query cluster.platformVersion`):
- Kubernetes version (use `aws eks describe-cluster --name <name> --query cluster.version`):
- AMI Version:
- Kernel (e.g. `uname -a`):
- Release information (run `cat /tmp/release` on a node):
<!-- Put release info in the triple backticks below-->
```
```

<!-- If this is a security issue, please do not discuss on GitHub. Please report any suspected or confirmed security issues to AWS Security https://aws.amazon.com/security/vulnerability-reporting/ -->
