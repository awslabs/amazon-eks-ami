# Changelog

### AMI Release v20230703
* amazon-eks-gpu-node-1.27-v20230703
* amazon-eks-gpu-node-1.26-v20230703
* amazon-eks-gpu-node-1.25-v20230703
* amazon-eks-gpu-node-1.24-v20230703
* amazon-eks-gpu-node-1.23-v20230703
* amazon-eks-gpu-node-1.22-v20230703
* amazon-eks-arm64-node-1.27-v20230703
* amazon-eks-arm64-node-1.26-v20230703
* amazon-eks-arm64-node-1.25-v20230703
* amazon-eks-arm64-node-1.24-v20230703
* amazon-eks-arm64-node-1.23-v20230703
* amazon-eks-arm64-node-1.22-v20230703
* amazon-eks-node-1.27-v20230703
* amazon-eks-node-1.26-v20230703
* amazon-eks-node-1.25-v20230703
* amazon-eks-node-1.24-v20230703
* amazon-eks-node-1.23-v20230703
* amazon-eks-node-1.22-v20230703

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.27.1-20230703`
* `1.26.4-20230703`
* `1.25.9-20230703`
* `1.24.13-20230703`
* `1.23.17-20230703`
* `1.22.17-20230703`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.27.1/2023-04-19/
* s3://amazon-eks/1.26.4/2023-05-11/
* s3://amazon-eks/1.25.9/2023-05-11/
* s3://amazon-eks/1.24.13/2023-05-11/
* s3://amazon-eks/1.23.17/2023-05-11/
* s3://amazon-eks/1.22.17/2023-05-11/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.247-162.350.amzn2
  * Kubernetes 1.24 and above: 5.10.184-175.731.amzn2
* `dockerd`: 20.10.23-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.5-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
- This is the last AMI release for Kubernetes 1.22
- Update Kernel to 5.4.247-162.350.amzn2 to address [ALASKERNEL-5.4-2023-048](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2023-048.html), [CVE-2023-1206](https://alas.aws.amazon.com/cve/html/CVE-2023-1206.html)
- Update Kernel to 5.10.184-175.731.amzn2 to address [ALASKERNEL-5.10-2023-035](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.10-2023-035.html), [CVE-2023-1206](https://alas.aws.amazon.com/cve/html/CVE-2023-1206.html)
- Use recommended clocksources ([#1328](https://github.com/awslabs/amazon-eks-ami/pull/1328))
- Add configurable working directory ([#1231](https://github.com/awslabs/amazon-eks-ami/pull/1231))
- Update eni-max-pods.txt ([#1330](https://github.com/awslabs/amazon-eks-ami/pull/1330))
- Mount bpffs by default on 1.25+ ([#1320](https://github.com/awslabs/amazon-eks-ami/pull/1320))

### AMI Release v20230607
* amazon-eks-gpu-node-1.27-v20230607
* amazon-eks-gpu-node-1.26-v20230607
* amazon-eks-gpu-node-1.25-v20230607
* amazon-eks-gpu-node-1.24-v20230607
* amazon-eks-gpu-node-1.23-v20230607
* amazon-eks-gpu-node-1.22-v20230607
* amazon-eks-arm64-node-1.27-v20230607
* amazon-eks-arm64-node-1.26-v20230607
* amazon-eks-arm64-node-1.25-v20230607
* amazon-eks-arm64-node-1.24-v20230607
* amazon-eks-arm64-node-1.23-v20230607
* amazon-eks-arm64-node-1.22-v20230607
* amazon-eks-node-1.27-v20230607
* amazon-eks-node-1.26-v20230607
* amazon-eks-node-1.25-v20230607
* amazon-eks-node-1.24-v20230607
* amazon-eks-node-1.23-v20230607
* amazon-eks-node-1.22-v20230607

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.27.1-20230607`
* `1.26.4-20230607`
* `1.25.9-20230607`
* `1.24.13-20230607`
* `1.23.17-20230607`
* `1.22.17-20230607`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.27.1/2023-04-19/
* s3://amazon-eks/1.26.4/2023-05-11/
* s3://amazon-eks/1.25.9/2023-05-11/
* s3://amazon-eks/1.24.13/2023-05-11/
* s3://amazon-eks/1.23.17/2023-05-11/
* s3://amazon-eks/1.22.17/2023-05-11/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.242-156.349.amzn2
  * Kubernetes 1.24 and above: 5.10.179-168.710.amzn2
* `dockerd`: 20.10.23-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.5-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
* `5.4` kernel update to `5.4.242-156.349.amzn2` and `5.10` kernel update to `5.10.179-168.710.amzn2` address [CVE-2023-32233](https://alas.aws.amazon.com/cve/html/CVE-2023-32233.html)
* Updating `runc` version to `1.1.5-1.amzn2` which contains fixes for [CVE-2023-28642](https://explore.alas.aws.amazon.com/CVE-2023-27561.html) and [CVE-2023-27561](https://explore.alas.aws.amazon.com/CVE-2023-28642.html).

### AMI Release v20230526
* amazon-eks-gpu-node-1.27-v20230526
* amazon-eks-gpu-node-1.26-v20230526
* amazon-eks-gpu-node-1.25-v20230526
* amazon-eks-gpu-node-1.24-v20230526
* amazon-eks-gpu-node-1.23-v20230526
* amazon-eks-gpu-node-1.22-v20230526
* amazon-eks-arm64-node-1.27-v20230526
* amazon-eks-arm64-node-1.26-v20230526
* amazon-eks-arm64-node-1.25-v20230526
* amazon-eks-arm64-node-1.24-v20230526
* amazon-eks-arm64-node-1.23-v20230526
* amazon-eks-arm64-node-1.22-v20230526
* amazon-eks-node-1.27-v20230526
* amazon-eks-node-1.26-v20230526
* amazon-eks-node-1.25-v20230526
* amazon-eks-node-1.24-v20230526
* amazon-eks-node-1.23-v20230526
* amazon-eks-node-1.22-v20230526

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.27.1-20230526`
* `1.26.4-20230526`
* `1.25.9-20230526`
* `1.24.13-20230526`
* `1.23.17-20230526`
* `1.22.17-20230526`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.27.1/2023-04-19/
* s3://amazon-eks/1.26.4/2023-05-11/
* s3://amazon-eks/1.25.9/2023-05-11/
* s3://amazon-eks/1.24.13/2023-05-11/
* s3://amazon-eks/1.23.17/2023-05-11/
* s3://amazon-eks/1.22.17/2023-05-11/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.242-155.348.amzn2
  * Kubernetes 1.24 and above: 5.10.179-166.674.amzn2
* `dockerd`: 20.10.23-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
* `5.4` kernel update to `5.4.242-155.348.amzn2` addresses CVE [ALAS2KERNEL-5.4-2023-045](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2023-045.html)
* `5.10` kernel update to `5.10.179-166.674.amzn2` addresses [ALAS2KERNEL-5.10-2023-032](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.10-2023-032.html)
* `Glib` update to `glib2-2.56.1-9.amzn2` addresses [ALAS-2023-2049](https://alas.aws.amazon.com/AL2/ALAS-2023-2049.html)

### AMI Release v20230513
* amazon-eks-gpu-node-1.27-v20230513
* amazon-eks-gpu-node-1.26-v20230513
* amazon-eks-gpu-node-1.25-v20230513
* amazon-eks-gpu-node-1.24-v20230513
* amazon-eks-gpu-node-1.23-v20230513
* amazon-eks-gpu-node-1.22-v20230513
* amazon-eks-arm64-node-1.27-v20230513
* amazon-eks-arm64-node-1.26-v20230513
* amazon-eks-arm64-node-1.25-v20230513
* amazon-eks-arm64-node-1.24-v20230513
* amazon-eks-arm64-node-1.23-v20230513
* amazon-eks-arm64-node-1.22-v20230513
* amazon-eks-node-1.27-v20230513
* amazon-eks-node-1.26-v20230513
* amazon-eks-node-1.25-v20230513
* amazon-eks-node-1.24-v20230513
* amazon-eks-node-1.23-v20230513
* amazon-eks-node-1.22-v20230513

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.27.1-20230513`
* `1.26.4-20230513`
* `1.25.9-20230513`
* `1.24.13-20230513`
* `1.23.17-20230513`
* `1.22.17-20230513`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.27.1/2023-04-19/
* s3://amazon-eks/1.26.4/2023-05-11/
* s3://amazon-eks/1.25.9/2023-05-11/
* s3://amazon-eks/1.24.13/2023-05-11/
* s3://amazon-eks/1.23.17/2023-05-11/
* s3://amazon-eks/1.22.17/2023-05-11/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.241-150.347.amzn2
  * Kubernetes 1.24 and above: 5.10.178-162.673.amzn2
* `dockerd`: 20.10.23-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
 - Add support for Kubernetes 1.27 ([#1300](https://github.com/awslabs/amazon-eks-ami/pull/1300))

Other changes:
 - Updated max pods for i4g instance types ([#1296](https://github.com/awslabs/amazon-eks-ami/commit/0de475c5f802acd470d9a2f1fdd521b7949a25ec))

### AMI Release v20230509
* amazon-eks-gpu-node-1.26-v20230509
* amazon-eks-gpu-node-1.25-v20230509
* amazon-eks-gpu-node-1.24-v20230509
* amazon-eks-gpu-node-1.23-v20230509
* amazon-eks-gpu-node-1.22-v20230509
* amazon-eks-arm64-node-1.26-v20230509
* amazon-eks-arm64-node-1.25-v20230509
* amazon-eks-arm64-node-1.24-v20230509
* amazon-eks-arm64-node-1.23-v20230509
* amazon-eks-arm64-node-1.22-v20230509
* amazon-eks-node-1.26-v20230509
* amazon-eks-node-1.25-v20230509
* amazon-eks-node-1.24-v20230509
* amazon-eks-node-1.23-v20230509
* amazon-eks-node-1.22-v20230509

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.26.2-20230509`
* `1.25.7-20230509`
* `1.24.11-20230509`
* `1.23.17-20230509`
* `1.22.17-20230509`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.26.2/2023-03-17/
* s3://amazon-eks/1.25.7/2023-03-17/
* s3://amazon-eks/1.24.11/2023-03-17/
* s3://amazon-eks/1.23.17/2023-03-17/
* s3://amazon-eks/1.22.17/2023-03-17/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.241-150.347.amzn2
  * Kubernetes 1.24 and above: 5.10.178-162.673.amzn2
* `dockerd`: 20.10.23-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
- The new AMIs have updated docker version 20.10.23-1.amzn2.0.1 that addresses two docker CVEs; [CVE-2022-36109 - docker](https://alas.aws.amazon.com/cve/html/CVE-2022-36109.html)  and [CVE-2022-37708 - docker](https://alas.aws.amazon.com/cve/html/CVE-2022-37708.html).
- For the GPU Variants of these AMIs, the Nvidia Fabric Manager version is upgraded from 470.161.03-1 to 470.182.03-1.
- Fix ECR pattern for aws-cn ([#1280](https://github.com/awslabs/amazon-eks-ami/pull/1280))
- Fix imds setting for multiple enis on ipv6 ([1275](https://github.com/awslabs/amazon-eks-ami/pull/1275))

### AMI Release v20230501
* amazon-eks-gpu-node-1.26-v20230501
* amazon-eks-gpu-node-1.25-v20230501
* amazon-eks-gpu-node-1.24-v20230501
* amazon-eks-gpu-node-1.23-v20230501
* amazon-eks-gpu-node-1.22-v20230501
* amazon-eks-arm64-node-1.26-v20230501
* amazon-eks-arm64-node-1.25-v20230501
* amazon-eks-arm64-node-1.24-v20230501
* amazon-eks-arm64-node-1.23-v20230501
* amazon-eks-arm64-node-1.22-v20230501
* amazon-eks-node-1.26-v20230501
* amazon-eks-node-1.25-v20230501
* amazon-eks-node-1.24-v20230501
* amazon-eks-node-1.23-v20230501
* amazon-eks-node-1.22-v20230501

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.26.2-20230501`
* `1.25.7-20230501`
* `1.24.11-20230501`
* `1.23.17-20230501`
* `1.22.17-20230501`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.26.2/2023-03-17/
* s3://amazon-eks/1.25.7/2023-03-17/
* s3://amazon-eks/1.24.11/2023-03-17/
* s3://amazon-eks/1.23.17/2023-03-17/
* s3://amazon-eks/1.22.17/2023-03-17/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.241-150.347.amzn2
  * Kubernetes 1.24 and above: 5.10.178-162.673.amzn2
* `dockerd`: 20.10.17-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
- Add bootstrap option to create a local NVMe raid0 or individual volume mounts ([#1171](https://github.com/awslabs/amazon-eks-ami/pull/1171))
- Improve bootstrap logging ([#1276](https://github.com/awslabs/amazon-eks-ami/pull/1276))
- Use credential provider API v1 in 1.27+, v1alpha1 in 1.26- ([#1269](https://github.com/awslabs/amazon-eks-ami/pull/1269))
- Override hostname to match EC2's PrivateDnsName ([#1264](https://github.com/awslabs/amazon-eks-ami/pull/1264))
- Add ethtool ([#1261](https://github.com/awslabs/amazon-eks-ami/pull/1261))
- Update `kernel-5.10` for [ALASKERNEL-5.10-2023-031](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.10-2023-031.html)
- Kernel version upgrade to `5.10.178-162.673.amzn2` fixes the [Containers failing to create and probe exec errors related to seccomp on recent kernel-5.10 versions](https://github.com/awslabs/amazon-eks-ami/issues/1219) issue


### AMI Release v20230411
* amazon-eks-gpu-node-1.26-v20230411
* amazon-eks-gpu-node-1.25-v20230411
* amazon-eks-gpu-node-1.24-v20230411
* amazon-eks-gpu-node-1.23-v20230411
* amazon-eks-gpu-node-1.22-v20230411
* amazon-eks-arm64-node-1.26-v20230411
* amazon-eks-arm64-node-1.25-v20230411
* amazon-eks-arm64-node-1.24-v20230411
* amazon-eks-arm64-node-1.23-v20230411
* amazon-eks-arm64-node-1.22-v20230411
* amazon-eks-node-1.26-v20230411
* amazon-eks-node-1.25-v20230411
* amazon-eks-node-1.24-v20230411
* amazon-eks-node-1.23-v20230411
* amazon-eks-node-1.22-v20230411

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.26.2-20230411`
* `1.25.7-20230411`
* `1.24.11-20230411`
* `1.23.17-20230411`
* `1.22.17-20230411`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.26.2/2023-03-17/
* s3://amazon-eks/1.25.7/2023-03-17/
* s3://amazon-eks/1.24.11/2023-03-17/
* s3://amazon-eks/1.23.17/2023-03-17/
* s3://amazon-eks/1.22.17/2023-03-17/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.238-148.347.amzn2
  * Kubernetes 1.24 and above: 5.10.176-157.645.amzn2
* `dockerd`: 20.10.17-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.4
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0

Notable changes:
- The AMI changes include update for 5.4 kernel version from `5.4.238-148.346.amzn2` to `kernel-5.4.238-148.347.amzn2`.  `kernel-5.4.238-148.346` had a fatal issue affecting SMB mounts in which a null pointer dereference caused a panic. As a result, this package was removed from the Amazon Linux 2 repositories.

### AMI Release v20230406
* amazon-eks-gpu-node-1.26-v20230406
* amazon-eks-gpu-node-1.25-v20230406
* amazon-eks-gpu-node-1.24-v20230406
* amazon-eks-gpu-node-1.23-v20230406
* amazon-eks-gpu-node-1.22-v20230406
* amazon-eks-arm64-node-1.26-v20230406
* amazon-eks-arm64-node-1.25-v20230406
* amazon-eks-arm64-node-1.24-v20230406
* amazon-eks-arm64-node-1.23-v20230406
* amazon-eks-arm64-node-1.22-v20230406
* amazon-eks-node-1.26-v20230406
* amazon-eks-node-1.25-v20230406
* amazon-eks-node-1.24-v20230406
* amazon-eks-node-1.23-v20230406
* amazon-eks-node-1.22-v20230406

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.26.2-20230406`
* `1.25.7-20230406`
* `1.24.11-20230406`
* `1.23.17-20230406`
* `1.22.17-20230406`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.26.2/2023-03-17/
* s3://amazon-eks/1.25.7/2023-03-17/
* s3://amazon-eks/1.24.11/2023-03-17/
* s3://amazon-eks/1.23.17/2023-03-17/
* s3://amazon-eks/1.22.17/2023-03-17/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.238-148.346.amzn2
  * Kubernetes 1.24 and above: 5.10.173-154.642.amzn2
* `dockerd`: 20.10.17-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.19-1.amzn2.0.1
* `runc`: 1.1.4
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0

Notable changes:
- Add support for Kubernetes 1.26 ([#1246](https://github.com/awslabs/amazon-eks-ami/pull/1246))
- Add support `inf2`, `trn1n` instance types ([#1251](https://github.com/awslabs/amazon-eks-ami/pull/1251))
- Updated `containerd` to address:
  - [ALASDOCKER-2023-023](https://alas.aws.amazon.com/AL2/ALASDOCKER-2023-023.html)
- Fixed `ecr-credential-provider` flags not being passed correctly to `kubelet` ([#1240](https://github.com/awslabs/amazon-eks-ami/pull/1240))
  - Added `--image-credential-provider-config` and `--image-credential-provider-bin-dir` flags to the `systemd` units.
  - Set `KubeletCredentialProviders` feature flag to `true` in the `kubelet` JSON config.

Other changes:
- Use `gp3 volume_type` for 1.27+ ([#1197](https://github.com/awslabs/amazon-eks-ami/pull/1197))
- Use default kubelet API QPS for 1.27+ ([#1241](https://github.com/awslabs/amazon-eks-ami/pull/1241))
- Remove `--container-runtime` kubelet flag for 1.27+ ([#1250](https://github.com/awslabs/amazon-eks-ami/pull/1250))

### AMI Release v20230322
* amazon-eks-gpu-node-1.25-v20230322
* amazon-eks-gpu-node-1.24-v20230322
* amazon-eks-gpu-node-1.23-v20230322
* amazon-eks-gpu-node-1.22-v20230322
* amazon-eks-arm64-node-1.25-v20230322
* amazon-eks-arm64-node-1.24-v20230322
* amazon-eks-arm64-node-1.23-v20230322
* amazon-eks-arm64-node-1.22-v20230322
* amazon-eks-node-1.25-v20230322
* amazon-eks-node-1.24-v20230322
* amazon-eks-node-1.23-v20230322
* amazon-eks-node-1.22-v20230322

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.25.7-20230322`
* `1.24.11-20230322`
* `1.23.17-20230322`
* `1.22.17-20230322`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.25.7/2023-03-17/
* s3://amazon-eks/1.24.11/2023-03-17/
* s3://amazon-eks/1.23.17/2023-03-17/
* s3://amazon-eks/1.22.17/2023-03-17/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.235-144.344.amzn2
  * Kubernetes 1.24 and above: 5.10.173-154.642.amzn2
  * The GPU AMI will continue to use `kernel-5.4` for all Kubernetes versions as we work to address a compatibility issue with `nvidia-driver-latest-dkms` ([#1222](https://github.com/awslabs/amazon-eks-ami/issues/1222)).
* `dockerd`: 20.10.17-1.amzn2.0.1
  * **Note** that with Kubernetes 1.25+, Docker is only installed on GPU AMI's. This is subject to change as we remove unnecessary dependencies, and we recommend completing the migration to `containerd` immediately.
* `containerd`: 1.6.6-1.amzn2.0.2
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
- Validate package versionlocks ([#1195](https://github.com/awslabs/amazon-eks-ami/pull/1195))
- Updated `kernel-5.4` to address:
  - [ALASKERNEL-5.4-2023-043](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2023-043.html)
- Updated `kernel-5.10` to address:
  - [ALASKERNEL-5.10-2023-027](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.10-2023-027.html)
  - [ALASKERNEL-5.10-2023-028](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.10-2023-028.html)

### AMI Release v20230304
* amazon-eks-gpu-node-1.25-v20230304
* amazon-eks-gpu-node-1.24-v20230304
* amazon-eks-gpu-node-1.23-v20230304
* amazon-eks-gpu-node-1.22-v20230304
* amazon-eks-gpu-node-1.21-v20230304
* amazon-eks-arm64-node-1.25-v20230304
* amazon-eks-arm64-node-1.24-v20230304
* amazon-eks-arm64-node-1.23-v20230304
* amazon-eks-arm64-node-1.22-v20230304
* amazon-eks-arm64-node-1.21-v20230304
* amazon-eks-node-1.25-v20230304
* amazon-eks-node-1.24-v20230304
* amazon-eks-node-1.23-v20230304
* amazon-eks-node-1.22-v20230304
* amazon-eks-node-1.21-v20230304

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.25.6-20230304`
* `1.24.10-20230304`
* `1.23.16-20230304`
* `1.22.17-20230304`
* `1.21.14-20230304`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.25.6/20230130/
* s3://amazon-eks/1.24.10/20230130/
* s3://amazon-eks/1.23.16/20230130/
* s3://amazon-eks/1.22.17/20230130/
* s3://amazon-eks/1.21.14/20230130/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.231-137.341.amzn2
  * Kubernetes 1.24 and above: 5.10.167-147.601.amzn2
* `dockerd`: 20.10.17-1.amzn2.0.1
  * **Note** that with Kubernetes 1.25+, Docker is only installed on GPU AMI's. This is subject to change as we remove unnecessary dependencies, and we recommend completing the migration to `containerd` immediately.
* `containerd`: 1.6.6-1.amzn2.0.2
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
- This is the last AMI release for Kubernetes 1.21
- This is the first AMI release available in `ap-southeast-4`

Minor changes:
- Adds a user guide section about packages in the versionlock file. [(#1199)](https://github.com/awslabs/amazon-eks-ami/pull/1199)

### AMI Release v20230217
* amazon-eks-gpu-node-1.25-v20230217
* amazon-eks-gpu-node-1.24-v20230217
* amazon-eks-gpu-node-1.23-v20230217
* amazon-eks-gpu-node-1.22-v20230217
* amazon-eks-gpu-node-1.21-v20230217
* amazon-eks-arm64-node-1.25-v20230217
* amazon-eks-arm64-node-1.24-v20230217
* amazon-eks-arm64-node-1.23-v20230217
* amazon-eks-arm64-node-1.22-v20230217
* amazon-eks-arm64-node-1.21-v20230217
* amazon-eks-node-1.25-v20230217
* amazon-eks-node-1.24-v20230217
* amazon-eks-node-1.23-v20230217
* amazon-eks-node-1.22-v20230217
* amazon-eks-node-1.21-v20230217

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.25.6-20230217`
* `1.24.10-20230217`
* `1.23.16-20230217`
* `1.22.17-20230217`
* `1.21.14-20230217`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.25.6/20230130/
* s3://amazon-eks/1.24.10/20230130/
* s3://amazon-eks/1.23.16/20230130/
* s3://amazon-eks/1.22.17/20230211/
* s3://amazon-eks/1.21.14/20230130/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.228-132.418.amzn2
  * Kubernetes 1.24 and above: 5.10.165-143.735.amzn2
* `dockerd`: 20.10.17-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.6-1.amzn2.0.2
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
- Kubernetes 1.24+ now use `kernel-5.10` for x86 and ARM AMIs.
  - The GPU AMI will continue to use `kernel-5.4` as we work to address a compatibility issue with `nvidia-driver-latest-dkms`.
- The `kernel` package is now properly version-locked [#1191](https://github.com/awslabs/amazon-eks-ami/pull/1191).
  - See [#1193](https://github.com/awslabs/amazon-eks-ami/issues/1193) for more information.
- New AMIs released for kubernetes version 1.25
- Pressure stall information (PSI) is now enabled [#1161](https://github.com/awslabs/amazon-eks-ami/pull/1161).

Minor changes:
- Updated `eni-max-pods.txt` with new instance types.
- Allow `kernel_version` to be set to any value (such as `5.15`) when building a custom AMI.

### [Recalled] AMI Release v20230211
* amazon-eks-gpu-node-1.25-v20230211
* amazon-eks-gpu-node-1.24-v20230211
* amazon-eks-gpu-node-1.23-v20230211
* amazon-eks-gpu-node-1.22-v20230211
* amazon-eks-gpu-node-1.21-v20230211
* amazon-eks-arm64-node-1.25-v20230211
* amazon-eks-arm64-node-1.24-v20230211
* amazon-eks-arm64-node-1.23-v20230211
* amazon-eks-arm64-node-1.22-v20230211
* amazon-eks-arm64-node-1.21-v20230211
* amazon-eks-node-1.25-v20230211
* amazon-eks-node-1.24-v20230211
* amazon-eks-node-1.23-v20230211
* amazon-eks-node-1.22-v20230211
* amazon-eks-node-1.21-v20230211

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.25.6-20230211`
* `1.24.10-20230211`
* `1.23.16-20230211`
* `1.22.17-20230211`
* `1.21.14-20230211`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.25.6/2023-01-30/
* s3://amazon-eks/1.24.10/2023-01-30/
* s3://amazon-eks/1.23.16/2023-01-30/
* s3://amazon-eks/1.22.17/2023-01-30/
* s3://amazon-eks/1.21.14/2023-01-30/

AMI details:
* `kernel`:
  * Kubernetes 1.23 and below: 5.4.228-132.418.amzn2
  * Kubernetes 1.24 and above: 5.10.165-143.735.amzn2
* `dockerd`: 20.10.17-1.amzn2.0.1
  * **Note** that Docker is not installed on AMI's with Kubernetes 1.25+.
* `containerd`: 1.6.6-1.amzn2.0.2
* `runc`: 1.1.4-1.amzn2
* `cuda`: 11.4.0-1
* `nvidia-container-runtime-hook`: 1.4.0-1.amzn2
* `amazon-ssm-agent`: 3.1.1732.0-1.amzn2

Notable changes:
- This is the first AMI release for Kubernetes 1.25.
- Kubernetes 1.24+ now use `kernel-5.10` for x86 and ARM AMIs.
  - The GPU AMI will continue to use `kernel-5.4` as we work to address a compatibility issue with `nvidia-driver-latest-dkms`.
- The `kernel` package is now version-locked.

Minor changes:
- Updated `eni-max-pods.txt` with new instance types.
- Allow `kernel_version` to be set to any value (such as `5.15`) when building a custom AMI.
- Fix a misconfiguration in the GPU AMI with `containerd`'s registry certificates. [#1168](https://github.com/awslabs/amazon-eks-ami/issues/1168).

### AMI Release v20230203
* amazon-eks-gpu-node-1.24-v20230203
* amazon-eks-gpu-node-1.23-v20230203
* amazon-eks-gpu-node-1.22-v20230203
* amazon-eks-gpu-node-1.21-v20230203
* amazon-eks-arm64-node-1.24-v20230203
* amazon-eks-arm64-node-1.23-v20230203
* amazon-eks-arm64-node-1.22-v20230203
* amazon-eks-arm64-node-1.21-v20230203
* amazon-eks-node-1.24-v20230203
* amazon-eks-node-1.23-v20230203
* amazon-eks-node-1.22-v20230203
* amazon-eks-node-1.21-v20230203

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.24.9-20230203`
* `1.23.15-20230203`
* `1.22.17-20230203`
* `1.21.14-20230203`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.24.9/2023-01-11/
* s3://amazon-eks/1.23.15/2023-01-11/
* s3://amazon-eks/1.22.17/2023-01-11/
* s3://amazon-eks/1.21.14/2023-01-11/

AMI details:
* kernel: 5.4.228-131.415.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: 1.1.4-1.amzn2
* cuda: 11.4.0-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
* Reverted [Use external cloud provider for EKS Local deployments](https://github.com/awslabs/amazon-eks-ami/commit/4b9b546dc325e6372e705f1e192f68395ce017db)

### AMI Release v20230127
* amazon-eks-gpu-node-1.24-v20230127
* amazon-eks-gpu-node-1.23-v20230127
* amazon-eks-gpu-node-1.22-v20230127
* amazon-eks-gpu-node-1.21-v20230127
* amazon-eks-arm64-node-1.24-v20230127
* amazon-eks-arm64-node-1.23-v20230127
* amazon-eks-arm64-node-1.22-v20230127
* amazon-eks-arm64-node-1.21-v20230127
* amazon-eks-node-1.24-v20230127
* amazon-eks-node-1.23-v20230127
* amazon-eks-node-1.22-v20230127
* amazon-eks-node-1.21-v20230127

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.24.9-20230127`
* `1.23.15-20230127`
* `1.22.17-20230127`
* `1.21.14-20230127`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.24.9/2023-01-11/
* s3://amazon-eks/1.23.15/2023-01-11/
* s3://amazon-eks/1.22.17/2023-01-11/
* s3://amazon-eks/1.21.14/2023-01-11/

AMI details:
* kernel: 5.4.228-131.415.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: 1.1.4-1.amzn2
* cuda: 11.4.0-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
- Updated kernel version to `5.4.228-131.415.amzn2` for:
  - [ALAS2KERNEL-5.4-2023-041](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2023-041.html).
- Add support for `C6in`, `M6in`, `M6idn`, `R6in`, `R6idn` and `Hpc6id` instances [#1153](https://github.com/awslabs/amazon-eks-ami/pull/1153)
- This is the first AMI release available in `ap-south-2`, `eu-central-2`, and `eu-south-2`.
- Cache image content without unpacking/snapshotting [#1144](https://github.com/awslabs/amazon-eks-ami/pull/1144)
  - Container image caching has been re-enabled for 1.24 AMI's.

Minor changes:
- Update AWS CLI to `2.9.18`
- Configure containerd registry certificates by default in the GPU AMI.

### AMI Release v20230105
* amazon-eks-gpu-node-1.24-v20230105
* amazon-eks-gpu-node-1.23-v20230105
* amazon-eks-gpu-node-1.22-v20230105
* amazon-eks-gpu-node-1.21-v20230105
* amazon-eks-gpu-node-1.20-v20230105
* amazon-eks-arm64-node-1.24-v20230105
* amazon-eks-arm64-node-1.23-v20230105
* amazon-eks-arm64-node-1.22-v20230105
* amazon-eks-arm64-node-1.21-v20230105
* amazon-eks-arm64-node-1.20-v20230105
* amazon-eks-node-1.24-v20230105
* amazon-eks-node-1.23-v20230105
* amazon-eks-node-1.22-v20230105
* amazon-eks-node-1.21-v20230105
* amazon-eks-node-1.20-v20230105

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.24.7-20230105`
* `1.23.13-20230105`
* `1.22.15-20230105`
* `1.21.14-20230105`
* `1.20.15-20230105`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.24.7/2022-10-31/
* s3://amazon-eks/1.23.13/2022-10-31/
* s3://amazon-eks/1.22.15/2022-10-31/
* s3://amazon-eks/1.21.14/2022-10-31/
* s3://amazon-eks/1.20.15/2022-10-31/

AMI details:
* kernel: 5.4.226-129.415.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: 1.1.4-1.amzn2
* cuda: 11.4.0-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
- This will be the last release for 1.20 AMI's.
- Decrease `launch_block_device_mappings_volume_size` to 4 ([#1143](https://github.com/awslabs/amazon-eks-ami/pull/1143)).
  - This fixes an issue with 4GiB launch block devices. More information is available in [#1142](https://github.com/awslabs/amazon-eks-ami/issues/1142).
- Container image caching has been disabled while we work to optimize the disk usage of this feature. This feature was only enabled for 1.24 AMI's in the previous release, [v20221222](https://github.com/awslabs/amazon-eks-ami/releases/tag/v20221222).

Minor changes:
- Update AWS CLI to `2.9.12`

### AMI Release v20221222
* amazon-eks-gpu-node-1.24-v20221222
* amazon-eks-gpu-node-1.23-v20221222
* amazon-eks-gpu-node-1.22-v20221222
* amazon-eks-gpu-node-1.21-v20221222
* amazon-eks-gpu-node-1.20-v20221222
* amazon-eks-arm64-node-1.24-v20221222
* amazon-eks-arm64-node-1.23-v20221222
* amazon-eks-arm64-node-1.22-v20221222
* amazon-eks-arm64-node-1.21-v20221222
* amazon-eks-arm64-node-1.20-v20221222
* amazon-eks-node-1.24-v20221222
* amazon-eks-node-1.23-v20221222
* amazon-eks-node-1.22-v20221222
* amazon-eks-node-1.21-v20221222
* amazon-eks-node-1.20-v20221222

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.24.7-20221222`
* `1.23.13-20221222`
* `1.22.15-20221222`
* `1.21.14-20221222`
* `1.20.15-20221222`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.24.7/2022-10-31/
* s3://amazon-eks/1.23.13/2022-10-31/
* s3://amazon-eks/1.22.15/2022-10-31/
* s3://amazon-eks/1.21.14/2022-10-31/
* s3://amazon-eks/1.20.15/2022-10-31/

AMI details:
* kernel: 5.4.226-129.415.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: 1.1.4-1.amzn2
* cuda: 11.4.0-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
- Kernel updated to `5.4.226-129.415.amzn2` for:
  - [ALASKERNEL-5.4-2022-040](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2022-040.html)
  - [ALASKERNEL-5.4-2022-039](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2022-039.html)
- NVIDIA driver updated to `470.161.03-1` to address security issues. More information is available in [NVIDIA security bulletin #5415](https://nvidia.custhelp.com/app/answers/detail/a_id/5415).
- Cache pause, vpc-cni, and kube-proxy images during build ([#938](https://github.com/awslabs/amazon-eks-ami/pull/938))
  - *Note* that this has only been enabled for 1.24 AMIs at this time.
- Disable yum updates in cloud-init ([#1074](https://github.com/awslabs/amazon-eks-ami/pull/1074))
- Skip sandbox image pull if already present ([#1090](https://github.com/awslabs/amazon-eks-ami/pull/1090))
- Move variable defaults to `--var-file` ([#1079](https://github.com/awslabs/amazon-eks-ami/pull/1079))

Minor changes:
- Add ECR accounts for `eu-south-2`, `eu-central-2`, `ap-south-2` ([#1125](https://github.com/awslabs/amazon-eks-ami/pull/1125))
- Handle indentation when parsing `sandbox_image` from `containerd` config ([#1119](https://github.com/awslabs/amazon-eks-ami/pull/1119))
- Lookup instanceId using IMDSv2 in Windows log collector script ([#1116](https://github.com/awslabs/amazon-eks-ami/pull/1116))
- Remove `aws_region` and `binary_bucket_region` overrides from Makefile ([#1115](https://github.com/awslabs/amazon-eks-ami/pull/1115))
- Sym-link awscli to /bin ([#1102](https://github.com/awslabs/amazon-eks-ami/pull/1102))
- Configure containerd registry certificates by default ([#1049](https://github.com/awslabs/amazon-eks-ami/pull/1049))

### AMI Release v20221112
* amazon-eks-gpu-node-1.24-v20221112
* amazon-eks-gpu-node-1.23-v20221112
* amazon-eks-gpu-node-1.22-v20221112
* amazon-eks-gpu-node-1.21-v20221112
* amazon-eks-gpu-node-1.20-v20221112
* amazon-eks-arm64-node-1.24-v20221112
* amazon-eks-arm64-node-1.23-v20221112
* amazon-eks-arm64-node-1.22-v20221112
* amazon-eks-arm64-node-1.21-v20221112
* amazon-eks-arm64-node-1.20-v20221112
* amazon-eks-node-1.24-v20221112
* amazon-eks-node-1.23-v20221112
* amazon-eks-node-1.22-v20221112
* amazon-eks-node-1.21-v20221112
* amazon-eks-node-1.20-v20221112

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.24.7-20221112`
* `1.23.13-20221112`
* `1.22.15-20221112`
* `1.21.14-20221112`
* `1.20.15-20221112`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.24.7/2022-10-31/
* s3://amazon-eks/1.23.13/2022-10-31/
* s3://amazon-eks/1.22.15/2022-10-31/
* s3://amazon-eks/1.21.14/2022-10-31/
* s3://amazon-eks/1.20.15/2022-10-31/

AMI details:
* kernel: 5.4.219-126.411.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: runc-1.1.4-1.amzn2
* cuda: 470.141.03-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
* Upgrades `runc` to version `1.1.4`
* Updates [aws-iam-authenticator](https://github.com/kubernetes-sigs/aws-iam-authenticator) to version `0.5.10` and updates `kubelet` versions to `1.22.15`, `1.23.13` and `1.24.7`
* [Updates `client.authentication.k8s.io` to `v1beta1`](https://github.com/awslabs/amazon-eks-ami/commit/ce1c11f9db5bf5a730e978e74e13174d4b9f73a3)
* [Updates credential provider API to beta for Kubernetes versions `1.24+`](https://github.com/awslabs/amazon-eks-ami/commit/a521047d1b097b9c3dbb562ca9bdab5a641f347f)
* [Installs awscli v2 bundle when possible](https://github.com/awslabs/amazon-eks-ami/commit/794ed5f10842b436e10c9bc89ee41491a6494ade)

### AMI Release v20221104
* amazon-eks-gpu-node-1.24-v20221104
* amazon-eks-gpu-node-1.23-v20221104
* amazon-eks-gpu-node-1.22-v20221104
* amazon-eks-gpu-node-1.21-v20221104
* amazon-eks-gpu-node-1.20-v20221104
* amazon-eks-arm64-node-1.24-v20221104
* amazon-eks-arm64-node-1.23-v20221104
* amazon-eks-arm64-node-1.22-v20221104
* amazon-eks-arm64-node-1.21-v20221104
* amazon-eks-arm64-node-1.20-v20221104
* amazon-eks-node-1.24-v20221104
* amazon-eks-node-1.23-v20221104
* amazon-eks-node-1.22-v20221104
* amazon-eks-node-1.21-v20221104
* amazon-eks-node-1.20-v20221104

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.24.6-20221104`
* `1.23.9-20221104`
* `1.22.12-20221104`
* `1.21.14-20221104`
* `1.20.15-20221104`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.24.6/2022-10-05/
* s3://amazon-eks/1.23.9/2022-07-27/
* s3://amazon-eks/1.22.12/2022-07-27/
* s3://amazon-eks/1.21.14/2022-07-27/
* s3://amazon-eks/1.20.15/2022-07-27/

AMI details:
* kernel: 5.4.219-126.411.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: 1.1.3-1.amzn2.0.2
* cuda: 470.141.03-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
* Adds support for 1.24 with version 1.24.6
* Upgrades kernel at `5.4.219-126.411.amzn2` to address [known issues with the previous kernel version](https://github.com/awslabs/amazon-eks-ami/issues/1071)

### AMI Release v20221101
* amazon-eks-gpu-node-1.23-v20221101
* amazon-eks-gpu-node-1.22-v20221101
* amazon-eks-gpu-node-1.21-v20221101
* amazon-eks-gpu-node-1.20-v20221101
* amazon-eks-arm64-node-1.23-v20221101
* amazon-eks-arm64-node-1.22-v20221101
* amazon-eks-arm64-node-1.21-v20221101
* amazon-eks-arm64-node-1.20-v20221101
* amazon-eks-node-1.23-v20221101
* amazon-eks-node-1.22-v20221101
* amazon-eks-node-1.21-v20221101
* amazon-eks-node-1.20-v20221101

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.23.9-20221101`
* `1.22.12-20221101`
* `1.21.14-20221101`
* `1.20.15-20221101`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.23.9/2022-07-27/
* s3://amazon-eks/1.22.12/2022-07-27/
* s3://amazon-eks/1.21.14/2022-07-27/
* s3://amazon-eks/1.20.15/2022-07-27/

AMI details:
* kernel: 5.4.209-116.367.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: 1.1.3-1.amzn2.0.2
* cuda: 470.141.03-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
* Pin Kernel 5.4 to 5.4.209-116.367 to prevent nodes from going into Unready [#1072](https://github.com/awslabs/amazon-eks-ami/pull/1072)
* Increase the kube-api-server QPS from 5/10 to 10/20 [#1030](https://github.com/awslabs/amazon-eks-ami/pull/1030) 
* Update docker and containerd for [ALASDOCKER-2022-021](https://alas.aws.amazon.com/AL2/ALASDOCKER-2022-021.html) [#1056](https://github.com/awslabs/amazon-eks-ami/pull/1056) 
* runc version is updated to 1.1.3-1.amzn2.0.2 to include ALAS2DOCKER-2022-020 [#1055](https://github.com/awslabs/amazon-eks-ami/pull/1055)
* Release AMI in me-central-1 with version 1.21, 1.22, 1.23. 1.20 is not supported in this region since it will be deprecated soon.
* Fixes an issue with Docker daemon configuration on the GPU AMI (#351).
  * **Note** that if you have a workaround in place for this issue, you'll likely need to revert it.

### [Recalled] AMI Release v20221027
* amazon-eks-gpu-node-1.23-v20221027
* amazon-eks-gpu-node-1.22-v20221027
* amazon-eks-gpu-node-1.21-v20221027
* amazon-eks-gpu-node-1.20-v20221027
* amazon-eks-arm64-node-1.23-v20221027
* amazon-eks-arm64-node-1.22-v20221027
* amazon-eks-arm64-node-1.21-v20221027
* amazon-eks-arm64-node-1.20-v20221027
* amazon-eks-node-1.23-v20221027
* amazon-eks-node-1.22-v20221027
* amazon-eks-node-1.21-v20221027
* amazon-eks-node-1.20-v20221027

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.23.9-20221027`
* `1.22.12-20221027`
* `1.21.14-20221027`
* `1.20.15-20221027`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.23.9/2022-07-27/
* s3://amazon-eks/1.22.12/2022-07-27/
* s3://amazon-eks/1.21.14/2022-07-27/
* s3://amazon-eks/1.20.15/2022-07-27/

AMI details:
* kernel: 5.4.217-126.408.amzn2
* dockerd: 20.10.17-1.amzn2.0.1
* containerd: 1.6.6-1.amzn2.0.2
* runc: 1.1.3-1.amzn2.0.2
* cuda: 470.141.03-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
* cuda is updated to 470.141.03-1.
* Linux kernel is updated to 5.4.217-126.408.amzn2.
* runc version is updated to 1.1.3-1.amzn2.0.2 to include [ALAS2DOCKER-2022-020](https://alas.aws.amazon.com/AL2/ALASDOCKER-2022-020.html). [#1055](https://github.com/awslabs/amazon-eks-ami/pull/1055)
* docker version are update to 20.10.17-1.amzn2.0.1, and containerd version are updated to 1.6.6-1.amzn2.0.2 to include [ALASDOCKER-2022-021](https://alas.aws.amazon.com/AL2/ALASDOCKER-2022-021.html). [#1056](https://github.com/awslabs/amazon-eks-ami/pull/1056)
* Increase the kube-api-server QPS from 5/10 to 10/20. [#1030](https://github.com/awslabs/amazon-eks-ami/pull/1030)
* Release AMI in me-central-1 with version 1.21, 1.22, 1.23. 1.20 will not be supported since it will be deprecated soon.

### AMI Release v20220926
* amazon-eks-gpu-node-1.23-v20220926
* amazon-eks-gpu-node-1.22-v20220926
* amazon-eks-gpu-node-1.21-v20220926
* amazon-eks-gpu-node-1.20-v20220926
* amazon-eks-arm64-node-1.23-v20220926
* amazon-eks-arm64-node-1.22-v20220926
* amazon-eks-arm64-node-1.21-v20220926
* amazon-eks-arm64-node-1.20-v20220926
* amazon-eks-node-1.23-v20220926
* amazon-eks-node-1.22-v20220926
* amazon-eks-node-1.21-v20220926
* amazon-eks-node-1.20-v20220926

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.23.9-20220926`
* `1.22.12-20220926`
* `1.21.14-20220926`
* `1.20.15-20220926`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.23.9/2022-07-27/
* s3://amazon-eks/1.22.12/2022-07-27/
* s3://amazon-eks/1.21.14/2022-07-27/
* s3://amazon-eks/1.20.15/2022-07-27/

AMI details:
* kernel: 5.4.209-116.367.amzn2
* dockerd: 20.10.17-1.amzn2
* containerd: 1.6.6-1.amzn2
* runc: 1.1.3-1.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable Changes:
* Phase 1 of support for Trn1 instances

### AMI Release v20220914
* amazon-eks-gpu-node-1.23-v20220914
* amazon-eks-gpu-node-1.22-v20220914
* amazon-eks-gpu-node-1.21-v20220914
* amazon-eks-gpu-node-1.20-v20220914
* amazon-eks-arm64-node-1.23-v20220914
* amazon-eks-arm64-node-1.22-v20220914
* amazon-eks-arm64-node-1.21-v20220914
* amazon-eks-arm64-node-1.20-v20220914
* amazon-eks-node-1.23-v20220914
* amazon-eks-node-1.22-v20220914
* amazon-eks-node-1.21-v20220914
* amazon-eks-node-1.20-v20220914

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.23.9-20220914`
* `1.22.12-20220914`
* `1.21.14-20220914`
* `1.20.15-20220914`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.23.9/2022-07-27/
* s3://amazon-eks/1.22.12/2022-07-27/
* s3://amazon-eks/1.21.14/2022-07-27/
* s3://amazon-eks/1.20.15/2022-07-27/

AMI details:
* kernel: 5.4.209-116.367.amzn2
* dockerd: 20.10.17-1.amzn2
* containerd: 1.6.6-1.amzn2
* runc: 1.1.3-1.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1732.0-1.amzn2

Notable changes:
- The AWS CLI has been updated to (`1.25.72`)[https://github.com/aws/aws-cli/blob/1.25.72/CHANGELOG.rst#L8] to support local EKS clusters on Outposts.
- This release fixes an issue with DNS cluster IP and IPv6. More info in #931.
- Kernel version updated to `5.4.209-116.367.amzn2` as a part of latest CVE patch (ALASKERNEL-5.4-2022-035)[https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2022-035.html]

### AMI Release v20220824
* amazon-eks-gpu-node-1.23-v20220824
* amazon-eks-gpu-node-1.22-v20220824
* amazon-eks-gpu-node-1.21-v20220824
* amazon-eks-gpu-node-1.20-v20220824
* amazon-eks-gpu-node-1.19-v20220824
* amazon-eks-arm64-node-1.23-v20220824
* amazon-eks-arm64-node-1.22-v20220824
* amazon-eks-arm64-node-1.21-v20220824
* amazon-eks-arm64-node-1.20-v20220824
* amazon-eks-arm64-node-1.19-v20220824
* amazon-eks-node-1.23-v20220824
* amazon-eks-node-1.22-v20220824
* amazon-eks-node-1.21-v20220824
* amazon-eks-node-1.20-v20220824
* amazon-eks-node-1.19-v20220824

[Release versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-linux-ami-versions.html) for these AMIs:
* `1.23.9-20220824`
* `1.22.12-20220824`
* `1.21.14-20220824`
* `1.20.15-20220824`
* `1.19.15-20220824`

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.23.9/2022-07-27/
* s3://amazon-eks/1.22.12/2022-07-27/
* s3://amazon-eks/1.21.14/2022-07-27/
* s3://amazon-eks/1.20.15/2022-07-27/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.209-116.363.amzn2
* dockerd: 20.10.17-1.amzn2 
* containerd: 1.6.6-1.amzn2 
* runc: 1.1.3-1.amzn2-1.amzn2 
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1575.0-1.amzn2

Notable changes:
* We are updating the versions of docker, containerd and runc as part of this AMI release.
* Kernel version is also updated to include the [latest CVE patches](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2022-034.html)
* This is the last release for 1.19 as we are at [end of support for 1.19](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html#kubernetes-release-calendar)

### AMI Release v20220811
* amazon-eks-gpu-node-1.23-v20220811
* amazon-eks-gpu-node-1.22-v20220811
* amazon-eks-gpu-node-1.21-v20220811
* amazon-eks-gpu-node-1.20-v20220811
* amazon-eks-gpu-node-1.19-v20220811
* amazon-eks-arm64-node-1.23-v20220811
* amazon-eks-arm64-node-1.22-v20220811
* amazon-eks-arm64-node-1.21-v20220811
* amazon-eks-arm64-node-1.20-v20220811
* amazon-eks-arm64-node-1.19-v20220811
* amazon-eks-node-1.23-v20220811
* amazon-eks-node-1.22-v20220811
* amazon-eks-node-1.21-v20220811
* amazon-eks-node-1.20-v20220811
* amazon-eks-node-1.19-v20220811

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.23.9/2022-07-27/
* s3://amazon-eks/1.22.12/2022-07-27/
* s3://amazon-eks/1.21.14/2022-07-27/
* s3://amazon-eks/1.20.15/2022-07-27/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.204-113.362.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-3.amzn2
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1575.0-1.amzn2

Notable changes:
- Kubelet binaries updated, including a backport of [#109676](https://github.com/kubernetes/kubernetes/pull/109676).
- When using `containerd` as the container runtime, `systemd` will now be used as the cgroup driver. For more information, see [the Kubernetes documentation](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/).
- Updated `aws-neuron-dkms` to `2.3.26` to address [a security issue](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/release-notes/neuron-driver.html#ndriver-2-3-26-0). This is a recommended upgrade for all users of the GPU AMI.

### AMI Release v20220802
* amazon-eks-gpu-node-1.23-v20220802
* amazon-eks-gpu-node-1.22-v20220802
* amazon-eks-gpu-node-1.21-v20220802
* amazon-eks-gpu-node-1.20-v20220802
* amazon-eks-gpu-node-1.19-v20220802
* amazon-eks-arm64-node-1.23-v20220802
* amazon-eks-arm64-node-1.22-v20220802
* amazon-eks-arm64-node-1.21-v20220802
* amazon-eks-arm64-node-1.20-v20220802
* amazon-eks-arm64-node-1.19-v20220802
* amazon-eks-node-1.23-v20220802
* amazon-eks-node-1.22-v20220802
* amazon-eks-node-1.21-v20220802
* amazon-eks-node-1.20-v20220802
* amazon-eks-node-1.19-v20220802

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.23.7/2022-06-29/
* s3://amazon-eks/1.22.9/2022-03-09/
* s3://amazon-eks/1.21.12/2022-05-20/
* s3://amazon-eks/1.20.15/2022-06-20/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.204-113.362.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-3.amzn2
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1575.0-1.amzn2

Notable changes:
* Release 1.23 AMIs publicly

### AMI Release v20220725
* amazon-eks-gpu-node-1.22-v20220725
* amazon-eks-gpu-node-1.21-v20220725
* amazon-eks-gpu-node-1.20-v20220725
* amazon-eks-gpu-node-1.19-v20220725
* amazon-eks-arm64-node-1.22-v20220725
* amazon-eks-arm64-node-1.21-v20220725
* amazon-eks-arm64-node-1.20-v20220725
* amazon-eks-arm64-node-1.19-v20220725
* amazon-eks-node-1.22-v20220725
* amazon-eks-node-1.21-v20220725
* amazon-eks-node-1.20-v20220725
* amazon-eks-node-1.19-v20220725

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.9/2022-03-09/
* s3://amazon-eks/1.21.12/2022-05-20/
* s3://amazon-eks/1.20.15/2022-06-20/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.204-113.362.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-3.amzn2
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1575.0

Notable changes:
* Updating pause-container version from 3.1 to 3.5
* Adding log-collector-script to the AMI
* Kernel version upgraded to 5.4.204-113.362.amzn2 for [CVE-2022-0494](https://alas.aws.amazon.com/cve/html/CVE-2022-0494.html) [CVE-2022-0812](https://alas.aws.amazon.com/cve/html/CVE-2022-0812.html) [CVE-2022-1012](https://alas.aws.amazon.com/cve/html/CVE-2022-1012.html) [CVE-2022-1184](https://alas.aws.amazon.com/cve/html/CVE-2022-1184.html) [CVE-2022-1966](https://alas.aws.amazon.com/cve/html/CVE-2022-1966.html) [CVE-2022-32250](https://alas.aws.amazon.com/cve/html/CVE-2022-32250.html) [CVE-2022-32296](https://alas.aws.amazon.com/cve/html/CVE-2022-32296.html) [CVE-2022-32981](https://alas.aws.amazon.com/cve/html/CVE-2022-32981.html)


### AMI Release v20220629
* amazon-eks-gpu-node-1.22-v20220629
* amazon-eks-gpu-node-1.21-v20220629
* amazon-eks-gpu-node-1.20-v20220629
* amazon-eks-gpu-node-1.19-v20220629
* amazon-eks-arm64-node-1.22-v20220629
* amazon-eks-arm64-node-1.21-v20220629
* amazon-eks-arm64-node-1.20-v20220629
* amazon-eks-arm64-node-1.19-v20220629
* amazon-eks-node-1.22-v20220629
* amazon-eks-node-1.21-v20220629
* amazon-eks-node-1.20-v20220629
* amazon-eks-node-1.19-v20220629

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.9/2022-03-09/
* s3://amazon-eks/1.21.12/2022-05-20/
* s3://amazon-eks/1.20.15/2022-06-20/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.196-108.356.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-3.amzn2
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0

Noted software versions are identical to release v20220620 in the commercial partition.

### AMI Release v20220620
* amazon-eks-gpu-node-1.22-v20220620
* amazon-eks-gpu-node-1.21-v20220620
* amazon-eks-gpu-node-1.20-v20220620
* amazon-eks-gpu-node-1.19-v20220620
* amazon-eks-arm64-node-1.22-v20220620
* amazon-eks-arm64-node-1.21-v20220620
* amazon-eks-arm64-node-1.20-v20220620
* amazon-eks-arm64-node-1.19-v20220620
* amazon-eks-node-1.22-v20220620
* amazon-eks-node-1.21-v20220620
* amazon-eks-node-1.20-v20220620
* amazon-eks-node-1.19-v20220620

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.9/2022-03-09/
* s3://amazon-eks/1.21.12/2022-05-20/
* s3://amazon-eks/1.20.15/2022-06-20/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.196-108.356.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-3.amzn2
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0

Notable changes:
* Update kubelet binaries for 1.20
* Support packer's ami_regions feature
* Increase /var/log/messages limit to 100M     
* Support local cluster in Outposts
* Adding c6id, m6id, r6id to eni-max-pods.txt

### AMI Release v20220610
* amazon-eks-gpu-node-1.22-v20220610
* amazon-eks-gpu-node-1.21-v20220610
* amazon-eks-gpu-node-1.20-v20220610
* amazon-eks-gpu-node-1.19-v20220610
* amazon-eks-arm64-node-1.22-v20220610
* amazon-eks-arm64-node-1.21-v20220610
* amazon-eks-arm64-node-1.20-v20220610
* amazon-eks-arm64-node-1.19-v20220610
* amazon-eks-node-1.22-v20220610
* amazon-eks-node-1.21-v20220610
* amazon-eks-node-1.20-v20220610
* amazon-eks-node-1.19-v20220610

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.9/2022-06-03/
* s3://amazon-eks/1.21.12/2022-05-20/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.196-108.356.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-3.amzn2
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0

Notable changes:
* Containerd version upgraded to 1.4.13-3.amzn2 for [CVE-2022-31030](https://alas.aws.amazon.com/cve/html/CVE-2022-31030.html).
* Kernel version upgraded to 5.4.196-108.356.amzn2 for [CVE-2022-0494](https://alas.aws.amazon.com/cve/html/CVE-2022-0494.html), [CVE-2022-0854](https://alas.aws.amazon.com/cve/html/CVE-2022-0854.html), [CVE-2022-1729](https://alas.aws.amazon.com/cve/html/CVE-2022-1729.html), [CVE-2022-1836](https://alas.aws.amazon.com/cve/html/CVE-2022-1836.html), [CVE-2022-28893](https://alas.aws.amazon.com/cve/html/CVE-2022-28893.html), [CVE-2022-29581](https://alas.aws.amazon.com/cve/html/CVE-2022-29581.html)
* Updating the kubelet version for 1.22 from 1.22.6 to 1.22.9

### AMI Release v20220526
* amazon-eks-gpu-node-1.22-v20220526
* amazon-eks-gpu-node-1.21-v20220526
* amazon-eks-gpu-node-1.20-v20220526
* amazon-eks-gpu-node-1.19-v20220526
* amazon-eks-arm64-node-1.22-v20220526
* amazon-eks-arm64-node-1.21-v20220526
* amazon-eks-arm64-node-1.20-v20220526
* amazon-eks-arm64-node-1.19-v20220526
* amazon-eks-node-1.22-v20220526
* amazon-eks-node-1.21-v20220526
* amazon-eks-node-1.20-v20220526
* amazon-eks-node-1.19-v20220526

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.6/2022-03-09/
* s3://amazon-eks/1.21.12/2022-05-20/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.190-107.353.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-2.amzn2.0.1
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0

Notable changes:
Linux kernel upgraded to 5.4.190-107.353.

### AMI Release v20220523
* amazon-eks-gpu-node-1.22-v20220523
* amazon-eks-gpu-node-1.21-v20220523
* amazon-eks-gpu-node-1.20-v20220523
* amazon-eks-gpu-node-1.19-v20220523
* amazon-eks-arm64-node-1.22-v20220523
* amazon-eks-arm64-node-1.21-v20220523
* amazon-eks-arm64-node-1.20-v20220523
* amazon-eks-arm64-node-1.19-v20220523
* amazon-eks-node-1.22-v20220523
* amazon-eks-node-1.21-v20220523
* amazon-eks-node-1.20-v20220523
* amazon-eks-node-1.19-v20220523

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.6/2022-03-09/
* s3://amazon-eks/1.21.12/2022-05-20/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.190-107.353.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-2.amzn2.0.1
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0

Notable changes:
* Added i4i instance support
* Fixes regression in the docker group ID. AMI build will now fail if the docker group ID is not 1950.
* Removes unused kernels (such as 4.14) during AMI build. This prevents false-positives from automated scanning tools such as AWS Inspector.
* Maintain dockershim compatibility symlink after instance reboot
* Updates 1.21 kubelet version to 1.21.12

### [Recalled] AMI Release v20220513
* amazon-eks-gpu-node-1.22-v20220513
* amazon-eks-gpu-node-1.21-v20220513
* amazon-eks-gpu-node-1.20-v20220513
* amazon-eks-gpu-node-1.19-v20220513
* amazon-eks-arm64-node-1.22-v20220513
* amazon-eks-arm64-node-1.21-v20220513
* amazon-eks-arm64-node-1.20-v20220513
* amazon-eks-arm64-node-1.19-v20220513
* amazon-eks-node-1.22-v20220513
* amazon-eks-node-1.21-v20220513
* amazon-eks-node-1.20-v20220513
* amazon-eks-node-1.19-v20220513

Notice:
* EKS-Optimized AMI SSM parameters contained an incorrect reference to the release version of the AMIs in this release.

### AMI Release v20220429
* amazon-eks-gpu-node-1.22-v20220429
* amazon-eks-gpu-node-1.21-v20220429
* amazon-eks-gpu-node-1.20-v20220429
* amazon-eks-gpu-node-1.19-v20220429
* amazon-eks-arm64-node-1.22-v20220429
* amazon-eks-arm64-node-1.21-v20220429
* amazon-eks-arm64-node-1.20-v20220429
* amazon-eks-arm64-node-1.19-v20220429
* amazon-eks-node-1.22-v20220429
* amazon-eks-node-1.21-v20220429
* amazon-eks-node-1.20-v20220429
* amazon-eks-node-1.19-v20220429

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.6/2022-03-09/
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.188-104.359.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-2.amzn2.0.1
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0-1.amzn2

Notable changes:
* Added c7g support
* [When replaying user-data in testing will bail user-data when strict due to moving files](https://github.com/awslabs/amazon-eks-ami/pull/893/files)

### AMI Release v20220421
* amazon-eks-gpu-node-1.22-v20220421
* amazon-eks-gpu-node-1.21-v20220421
* amazon-eks-gpu-node-1.20-v20220421
* amazon-eks-gpu-node-1.19-v20220421
* amazon-eks-arm64-node-1.22-v20220421
* amazon-eks-arm64-node-1.21-v20220421
* amazon-eks-arm64-node-1.20-v20220421
* amazon-eks-arm64-node-1.19-v20220421
* amazon-eks-node-1.22-v20220421
* amazon-eks-node-1.21-v20220421
* amazon-eks-node-1.20-v20220421
* amazon-eks-node-1.19-v20220421

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.6/2022-03-09/
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.188-104.359.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-2.amzn2.0.1
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0-1.amzn2

Notable changes:
* Includes patched Kernel for [CVE-2022-26490](https://alas.aws.amazon.com/cve/html/CVE-2022-26490.html), [CVE-2022-27666](https://alas.aws.amazon.com/cve/html/CVE-2022-27666.html) and [CVE-2022-28356](https://alas.aws.amazon.com/cve/html/CVE-2022-28356.html)
* New release with AMIs now available in ap-southeast-3

### AMI Release v20220420
* amazon-eks-gpu-node-1.22-v20220420
* amazon-eks-gpu-node-1.21-v20220420
* amazon-eks-gpu-node-1.20-v20220420
* amazon-eks-gpu-node-1.19-v20220420
* amazon-eks-arm64-node-1.22-v20220420
* amazon-eks-arm64-node-1.21-v20220420
* amazon-eks-arm64-node-1.20-v20220420
* amazon-eks-arm64-node-1.19-v20220420
* amazon-eks-node-1.22-v20220420
* amazon-eks-node-1.21-v20220420
* amazon-eks-node-1.20-v20220420
* amazon-eks-node-1.19-v20220420

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.6/2022-03-09/
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/

AMI details:
* kernel: 5.4.188-104.359.amzn2
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-2.amzn2.0.1
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.1.1188.0

Notable changes:
- Patches for [CVE-2022-0778](https://nvd.nist.gov/vuln/detail/CVE-2022-0778), [CVE-2022-23218](https://nvd.nist.gov/vuln/detail/CVE-2022-23218) and [CVE-2022-23219](https://nvd.nist.gov/vuln/detail/CVE-2022-23219) have been included.
- Deprecating 1.18 k8s Version

### AMI Release v20220406
* amazon-eks-gpu-node-1.22-v20220406
* amazon-eks-gpu-node-1.21-v20220406
* amazon-eks-gpu-node-1.20-v20220406
* amazon-eks-gpu-node-1.19-v20220406
* amazon-eks-gpu-node-1.18-v20220406
* amazon-eks-arm64-node-1.22-v20220406
* amazon-eks-arm64-node-1.21-v20220406
* amazon-eks-arm64-node-1.20-v20220406
* amazon-eks-arm64-node-1.19-v20220406
* amazon-eks-arm64-node-1.18-v20220406
* amazon-eks-node-1.22-v20220406
* amazon-eks-node-1.21-v20220406
* amazon-eks-node-1.20-v20220406
* amazon-eks-node-1.19-v20220406
* amazon-eks-node-1.18-v20220406

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.6/2022-03-09/
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.181-99.354.amzn2 (1.19 and above), 4.14.268-205.500.amzn2 (1.18 and below)
* dockerd: 20.10.13-2.amzn2
* containerd: 1.4.13-2.amzn2.0.1
* runc: 1.0.3-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
- Patches for [CVE-2022-24769](https://nvd.nist.gov/vuln/detail/CVE-2022-24769) have been included.
- The bootstrap script will auto-discover maxPods values when instanceType is missing in eni-max-pods.txt

### AMI Release v20220317
* amazon-eks-gpu-node-1.22-v20220317
* amazon-eks-gpu-node-1.21-v20220317
* amazon-eks-gpu-node-1.20-v20220317
* amazon-eks-gpu-node-1.19-v20220317
* amazon-eks-gpu-node-1.18-v20220317
* amazon-eks-arm64-node-1.22-v20220317
* amazon-eks-arm64-node-1.21-v20220317
* amazon-eks-arm64-node-1.20-v20220317
* amazon-eks-arm64-node-1.19-v20220317
* amazon-eks-arm64-node-1.18-v20220317
* amazon-eks-node-1.22-v20220317
* amazon-eks-node-1.21-v20220317
* amazon-eks-node-1.20-v20220317
* amazon-eks-node-1.19-v20220317
* amazon-eks-node-1.18-v20220317

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.22.6/2022-03-09/
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.181-99.354.amzn2 (1.19 and above), 4.14.268-205.500.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-8.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
- Adding support for new k8s version 1.22

### AMI Release v20220309
* amazon-eks-gpu-node-1.21-v20220309
* amazon-eks-gpu-node-1.20-v20220309
* amazon-eks-gpu-node-1.19-v20220309
* amazon-eks-gpu-node-1.18-v20220309
* amazon-eks-arm64-node-1.21-v20220309
* amazon-eks-arm64-node-1.20-v20220309
* amazon-eks-arm64-node-1.19-v20220309
* amazon-eks-arm64-node-1.18-v20220309
* amazon-eks-node-1.21-v20220309
* amazon-eks-node-1.20-v20220309
* amazon-eks-node-1.19-v20220309
* amazon-eks-node-1.18-v20220309

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.181-99.354.amzn2 (1.19 and above), 4.14.268-205.500.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-8.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
- Update kernel version to 4.14.268-205.500.amzn2 for 1.18 and below, 5.4.181-99.354.amzn2 for 1.19 and above. For more information, see [ALAS-2022-1761](https://alas.aws.amazon.com/AL2/ALAS-2022-1761.html) and [ALASKERNEL-5.4-2022-023](https://alas.aws.amazon.com/AL2/ALASKERNEL-5.4-2022-023.html).

### AMI Release v20220303
* amazon-eks-gpu-node-1.21-v20220303
* amazon-eks-gpu-node-1.20-v20220303
* amazon-eks-gpu-node-1.19-v20220303
* amazon-eks-gpu-node-1.18-v20220303
* amazon-eks-arm64-node-1.21-v20220303
* amazon-eks-arm64-node-1.20-v20220303
* amazon-eks-arm64-node-1.19-v20220303
* amazon-eks-arm64-node-1.18-v20220303
* amazon-eks-node-1.21-v20220303
* amazon-eks-node-1.20-v20220303
* amazon-eks-node-1.19-v20220303
* amazon-eks-node-1.18-v20220303

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.176-91.338.amzn2 (1.19 and above), 4.14.262-200.489.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-8.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
- Update `containerd` to `1.4.6-8.amzn2` for CVE-2022-23648.

### AMI Release v20220226
* amazon-eks-gpu-node-1.21-v20220226
* amazon-eks-gpu-node-1.20-v20220226
* amazon-eks-gpu-node-1.19-v20220226
* amazon-eks-gpu-node-1.18-v20220226
* amazon-eks-arm64-node-1.21-v20220226
* amazon-eks-arm64-node-1.20-v20220226
* amazon-eks-arm64-node-1.19-v20220226
* amazon-eks-arm64-node-1.18-v20220226
* amazon-eks-node-1.21-v20220226
* amazon-eks-node-1.20-v20220226
* amazon-eks-node-1.19-v20220226
* amazon-eks-node-1.18-v20220226

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2022-01-21/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.176-91.338.amzn2 (1.19 and above), 4.14.262-200.489.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-7.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
- Upgrade `ec2-utils` version to `1.2-47`, addressing an issue with device symbolic links. More information is available [here](https://github.com/aws/amazon-ec2-utils/issues/22).

### AMI Release v20220216
* amazon-eks-gpu-node-1.21-v20220216
* amazon-eks-gpu-node-1.20-v20220216
* amazon-eks-gpu-node-1.19-v20220216
* amazon-eks-gpu-node-1.18-v20220216
* amazon-eks-arm64-node-1.21-v20220216
* amazon-eks-arm64-node-1.20-v20220216
* amazon-eks-arm64-node-1.19-v20220216
* amazon-eks-arm64-node-1.18-v20220216
* amazon-eks-node-1.21-v20220216
* amazon-eks-node-1.20-v20220216
* amazon-eks-node-1.19-v20220216
* amazon-eks-node-1.18-v20220216

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2022-01-21/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.176-91.338.amzn2 (1.19 and above), 4.14.262-200.489.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-7.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
- Support for `c6a` instance types.

### AMI Release v20220210
* amazon-eks-gpu-node-1.21-v20220210
* amazon-eks-gpu-node-1.20-v20220210
* amazon-eks-gpu-node-1.19-v20220210
* amazon-eks-gpu-node-1.18-v20220210
* amazon-eks-arm64-node-1.21-v20220210
* amazon-eks-arm64-node-1.20-v20220210
* amazon-eks-arm64-node-1.19-v20220210
* amazon-eks-arm64-node-1.18-v20220210
* amazon-eks-node-1.21-v20220210
* amazon-eks-node-1.20-v20220210
* amazon-eks-node-1.19-v20220210
* amazon-eks-node-1.18-v20220210

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2022-01-21/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.176-91.338.amzn2 (1.19 and above), 4.14.262-200.489.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-7.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02-1
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
- Upgrade kernel version for Kubernetes 1.18 to `4.14.262-200.489.amzn2`, addressing several CVE's. More information available in [ALAS2-2022-1749](https://alas.aws.amazon.com/AL2/ALAS-2022-1749.html)
- Support for `hpc6a` instance types.
- Removes support for the `chacha20-poly1305@openssh.com` cipher, which is not FIPS-compliant.

### AMI Release v20220123
 - amazon-eks-node-1.18-v20220123
 - amazon-eks-arm64-node-1.18-v20220123
 - amazon-eks-gpu-node-1.18-v20220123
 - amazon-eks-node-1.19-v20220123
 - amazon-eks-arm64-node-1.19-v20220123
 - amazon-eks-gpu-node-1.19-v20220123
 - amazon-eks-node-1.20-v20220123
 - amazon-eks-arm64-node-1.20-v20220123
 - amazon-eks-gpu-node-1.20-v20220123
 - amazon-eks-node-1.21-v20220123
 - amazon-eks-arm64-node-1.21-v20220123
 - amazon-eks-gpu-node-1.21-v20220123

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2022-01-21/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.172-90.336.amzn2 (1.19 and above), 4.14.256-197.484.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-7.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
* Upgrade kernel version for Kubernetes 1.19 and above to 5.4.172-90.336.amzn2.x86_64 for CVE-2022-0185
* Bug fix in kubelet for 1.21 AMIs to handle compacted IPv6 addresses returned by EC2 API. New Kubelet version: `v1.21.5-eks-9017834`

### AMI Release v20220112
* amazon-eks-gpu-node-1.21-v20220112
* amazon-eks-gpu-node-1.20-v20220112
* amazon-eks-gpu-node-1.19-v20220112
* amazon-eks-gpu-node-1.18-v20220112
* amazon-eks-arm64-node-1.21-v20220112
* amazon-eks-arm64-node-1.20-v20220112
* amazon-eks-arm64-node-1.19-v20220112
* amazon-eks-arm64-node-1.18-v20220112
* amazon-eks-node-1.21-v20220112
* amazon-eks-node-1.20-v20220112
* amazon-eks-node-1.19-v20220112
* amazon-eks-node-1.18-v20220112

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.162-86.275.amzn2 (1.19 and above), 4.14.256-197.484.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-7.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0-1.amzn2

Notable changes:
* Updating aws-cli ( aws-cli/1.22.32 ). Latest CLI is installed using the recommended steps [here](https://docs.aws.amazon.com/cli/v1/userguide/install-linux.html#install-linux-bundled). This change is specific to this AMI release.
* Added fix to handle failures when serviceIpv6Cidr isn't provided. Related issue: https://github.com/awslabs/amazon-eks-ami/issues/839.
* Added fix to make ipFamily check case-insensitive

### AMI Release v20211206
* amazon-eks-gpu-node-1.21-v20211206
* amazon-eks-gpu-node-1.20-v20211206
* amazon-eks-gpu-node-1.19-v20211206
* amazon-eks-gpu-node-1.18-v20211206
* amazon-eks-arm64-node-1.21-v20211206
* amazon-eks-arm64-node-1.20-v20211206
* amazon-eks-arm64-node-1.19-v20211206
* amazon-eks-arm64-node-1.18-v20211206
* amazon-eks-node-1.21-v20211206
* amazon-eks-node-1.20-v20211206
* amazon-eks-node-1.19-v20211206
* amazon-eks-node-1.18-v20211206

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/

AMI details:
* kernel: 5.4.156-83.273.amzn2 (1.19 and above), 4.14.252-195.483.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-7.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0-1.amzn2

Notable changes:
* Adds new instanceTypes to the eni-max-pods.txt file.
* Patch for [AL2/ALAS-2021-1722](https://alas.aws.amazon.com/AL2/ALAS-2021-1722.html).

### AMI Release v20211117
* amazon-eks-gpu-node-1.21-v20211117
* amazon-eks-gpu-node-1.20-v20211117
* amazon-eks-gpu-node-1.19-v20211117
* amazon-eks-gpu-node-1.18-v20211117
* amazon-eks-gpu-node-1.17-v20211117
* amazon-eks-arm64-node-1.21-v20211117
* amazon-eks-arm64-node-1.20-v20211117
* amazon-eks-arm64-node-1.19-v20211117
* amazon-eks-arm64-node-1.18-v20211117
* amazon-eks-arm64-node-1.17-v20211117
* amazon-eks-node-1.21-v20211117
* amazon-eks-node-1.20-v20211117
* amazon-eks-node-1.19-v20211117
* amazon-eks-node-1.18-v20211117
* amazon-eks-node-1.17-v20211117

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/
* s3://amazon-eks/1.17.17/2021-09-02/

AMI details:
* kernel: 5.4.156-83.273.amzn2 (1.19 and above), 4.14.252-195.483.amzn2 (1.18 and below)
* dockerd: 20.10.7-5.amzn2
* containerd: 1.4.6-7.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0-1.amzn2

Notable changes:
Update `containerd` to `1.4.6-7.amzn2` and `docker` to `20.10.7-5.amzn2` to patch vulnerabilities in [CVE-2021-41190](https://alas.aws.amazon.com/ALAS-2021-1551.html)

### AMI Release v20211109
* amazon-eks-gpu-node-1.21-v20211109
* amazon-eks-gpu-node-1.20-v20211109
* amazon-eks-gpu-node-1.19-v20211109
* amazon-eks-gpu-node-1.18-v20211109
* amazon-eks-gpu-node-1.17-v20211109
* amazon-eks-arm64-node-1.21-v20211109
* amazon-eks-arm64-node-1.20-v20211109
* amazon-eks-arm64-node-1.19-v20211109
* amazon-eks-arm64-node-1.18-v20211109
* amazon-eks-arm64-node-1.17-v20211109
* amazon-eks-node-1.21-v20211109
* amazon-eks-node-1.20-v20211109
* amazon-eks-node-1.19-v20211109
* amazon-eks-node-1.18-v20211109
* amazon-eks-node-1.17-v20211109

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.21.5/2021-11-10/
* s3://amazon-eks/1.20.11/2021-11-10/
* s3://amazon-eks/1.19.15/2021-11-10/
* s3://amazon-eks/1.18.20/2021-09-02/
* s3://amazon-eks/1.17.17/2021-09-02/

AMI details:
* kernel: 5.4.149-73.259.amzn2 (1.19 and above), 4.14.252-195.483.amzn2 (1.18 and below)
* dockerd: 20.10.7-3.amzn2
* containerd: 1.4.6-3.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 470.57.02
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:
* Upgrade kernel version for 1.17 and 1.18 to 4.14.252-195.483.amzn2
* Upgrade cuda version from 460.73.01 to 470.57.02
* Upgrade kubelet version
    * 1.19.14 -> 1.19.15
    * 1.20.10 -> 1.20.11
    * 1.21.4 -> 1.21.5
* Remove cbc ciphers and use following recommended ciphers
  * chacha20-poly1305@openssh.com
  * aes128-ctr
  * aes256-ctr
  * aes128-gcm@openssh.com
  * aes256-gcm@openssh.com

## AMI Release v20211013

* amazon-eks-gpu-node-1.21-v20211013
* amazon-eks-gpu-node-1.20-v20211013
* amazon-eks-gpu-node-1.19-v20211013
* amazon-eks-gpu-node-1.18-v20211013
* amazon-eks-gpu-node-1.17-v20211013
* amazon-eks-gpu-node-1.16-v20211013
* amazon-eks-arm64-node-1.21-v20211013
* amazon-eks-arm64-node-1.20-v20211013
* amazon-eks-arm64-node-1.19-v20211013
* amazon-eks-arm64-node-1.18-v20211013
* amazon-eks-arm64-node-1.17-v20211013
* amazon-eks-arm64-node-1.16-v20211013
* amazon-eks-node-1.21-v20211013
* amazon-eks-node-1.20-v20211013
* amazon-eks-node-1.19-v20211013
* amazon-eks-node-1.18-v20211013
* amazon-eks-node-1.17-v20211013
* amazon-eks-node-1.16-v20211013

Binaries used to build these AMIs are published:

* s3://amazon-eks/1.21.4/2021-10-12/
* s3://amazon-eks/1.20.10/2021-10-12/
* s3://amazon-eks/1.19.14/2021-10-12/
* s3://amazon-eks/1.18.20/2021-09-02/
* s3://amazon-eks/1.17.17/2021-09-02/
* s3://amazon-eks/1.16.15/2021-09-02/

AMI details:

* kernel: 5.4.149-73.259.amzn2 (1.19 and above), 4.14.248-189.473.amzn2 (1.18 and below)
* dockerd: 20.10.7-3.amzn2
* containerd: 1.4.6-3.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 460.73.01
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:

* A fix has been made to the GPU AMIs to ensure they work correctly with containerd as the container runtime.

## AMI Release v20211008

* amazon-eks-gpu-node-1.21-v20211008
* amazon-eks-gpu-node-1.20-v20211008
* amazon-eks-gpu-node-1.19-v20211008
* amazon-eks-gpu-node-1.18-v20211008
* amazon-eks-gpu-node-1.17-v20211008
* amazon-eks-gpu-node-1.16-v20211008
* amazon-eks-gpu-node-1.15-v20211008
* amazon-eks-arm64-node-1.21-v20211008
* amazon-eks-arm64-node-1.20-v20211008
* amazon-eks-arm64-node-1.19-v20211008
* amazon-eks-arm64-node-1.18-v20211008
* amazon-eks-arm64-node-1.17-v20211008
* amazon-eks-arm64-node-1.16-v20211008
* amazon-eks-arm64-node-1.15-v20211008
* amazon-eks-node-1.21-v20211008
* amazon-eks-node-1.20-v20211008
* amazon-eks-node-1.19-v20211008
* amazon-eks-node-1.18-v20211008
* amazon-eks-node-1.17-v20211008
* amazon-eks-node-1.16-v20211008
* amazon-eks-node-1.15-v20211008

Binaries used to build these AMIs are published:

* s3://amazon-eks/1.21.4/2021-10-12/
* s3://amazon-eks/1.20.10/2021-10-12/
* s3://amazon-eks/1.19.14/2021-10-12/
* s3://amazon-eks/1.18.20/2021-09-02/
* s3://amazon-eks/1.17.17/2021-09-02/
* s3://amazon-eks/1.16.15/2021-09-02/

AMI details:

* kernel: 5.4.149-73.259.amzn2 (1.19 and above), 4.14.248-189.473.amzn2 (1.18 and below)
* dockerd: 20.10.7-3.amzn2
* containerd: 1.4.6-3.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 460.73.01
* nvidia-container-runtime-hook: 1.4.0-1.amzn2
* SSM agent: 3.0.1124.0

Notable changes:

* kubelet binaries have been updated for Kubernetes versions 1.19, 1.20 and 1.21, which include [a patch to fix an issue where kubelet can fail to unmount volumes](https://github.com/kubernetes/kubernetes/pull/102576)

## AMI Release v20211004

* amazon-eks-gpu-node-1.20-v20211004
* amazon-eks-gpu-node-1.19-v20211004
* amazon-eks-gpu-node-1.18-v20211004
* amazon-eks-gpu-node-1.17-v20211004
* amazon-eks-gpu-node-1.16-v20211004
* amazon-eks-gpu-node-1.15-v20211004
* amazon-eks-arm64-node-1.20-v20211004
* amazon-eks-arm64-node-1.19-v20211004
* amazon-eks-arm64-node-1.18-v20211004
* amazon-eks-arm64-node-1.17-v20211004
* amazon-eks-arm64-node-1.16-v20211004
* amazon-eks-arm64-node-1.15-v20211004
* amazon-eks-node-1.20-v20211004
* amazon-eks-node-1.19-v20211004
* amazon-eks-node-1.18-v20211004
* amazon-eks-node-1.17-v20211004
* amazon-eks-node-1.16-v20211004
* amazon-eks-node-1.15-v20211004

Binaries used to build these AMIs are published:

* s3://amazon-eks/1.21.2/2021-04-12/
* s3://amazon-eks/1.20.7/2021-04-12/
* s3://amazon-eks/1.19.13/2021-01-05/
* s3://amazon-eks/1.18.20/2020-11-02/
* s3://amazon-eks/1.17.17/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/

AMI details:

* kernel: 5.4.149-73.259.amzn2 (1.19 and above), 4.14.246-187.474.amzn2 (1.18 and below)
* dockerd: 20.10.7-3.amzn2
* containerd: 1.4.6-3.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 460.73.01
* nvidia-container-runtime-hook: 460.73.01
* SSM agent: 3.0.1124.0

Notable changes:
* Created AMI released on the latest commit

## AMI Release v20211003

* amazon-eks-gpu-node-1.20-v20211003
* amazon-eks-gpu-node-1.19-v20211003
* amazon-eks-gpu-node-1.18-v20211003
* amazon-eks-gpu-node-1.17-v20211003
* amazon-eks-gpu-node-1.16-v20211003
* amazon-eks-gpu-node-1.15-v20211003
* amazon-eks-arm64-node-1.20-v20211003
* amazon-eks-arm64-node-1.19-v20211003
* amazon-eks-arm64-node-1.18-v20211003
* amazon-eks-arm64-node-1.17-v20211003
* amazon-eks-arm64-node-1.16-v20211003
* amazon-eks-arm64-node-1.15-v20211003
* amazon-eks-node-1.20-v20211003
* amazon-eks-node-1.19-v20211003
* amazon-eks-node-1.18-v20211003
* amazon-eks-node-1.17-v20211003
* amazon-eks-node-1.16-v20211003
* amazon-eks-node-1.15-v20211003

Binaries used to build these AMIs are published:

* s3://amazon-eks/1.21.2/2021-04-12/
* s3://amazon-eks/1.20.7/2021-04-12/
* s3://amazon-eks/1.19.13/2021-01-05/
* s3://amazon-eks/1.18.20/2020-11-02/
* s3://amazon-eks/1.17.17/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/

AMI details:

* kernel: 5.4.144-69.257.amzn2 (1.19 and above), (1.18 and below)
* dockerd: 20.10.7-3.amzn2
* containerd: 1.4.6-3.amzn2
* runc: 1.0.0-2.amzn2
* cuda: 460.73.01
* nvidia-container-runtime-hook: 460.73.01
* SSM agent: 3.0.1124.0

Notable changes:

* Updated version of RunC to 1.0.0-2.amzn2
* Updated version of Docker to 20.10.7-3.amzn2
* Updated version of Containerd to 1.4.6-3.amzn2
* Following CVEs are addressed Docker (CVE-2021-41089, CVE-2021-41091, CVE-2021-41092) and containerd (CVE-2021-41103)

## AMI Release v20211001

* amazon-eks-gpu-node-1.21-v20211001
* amazon-eks-gpu-node-1.20-v20211001
* amazon-eks-gpu-node-1.19-v20211001
* amazon-eks-gpu-node-1.18-v20211001
* amazon-eks-gpu-node-1.17-v20211001
* amazon-eks-gpu-node-1.16-v20211001
* amazon-eks-arm64-node-1.21-v20211001
* amazon-eks-arm64-node-1.20-v20211001
* amazon-eks-arm64-node-1.19-v20211001
* amazon-eks-arm64-node-1.18-v20211001
* amazon-eks-arm64-node-1.17-v20211001
* amazon-eks-arm64-node-1.16-v20211001
* amazon-eks-node-1.21-v20211001
* amazon-eks-node-1.20-v20211001
* amazon-eks-node-1.19-v20211001
* amazon-eks-node-1.18-v20211001
* amazon-eks-node-1.17-v20211001
* amazon-eks-node-1.16-v20211001

Binaries used to build these AMIs are published:

s3://amazon-eks/1.20.4/2021-04-12/
s3://amazon-eks/1.19.6/2021-01-05/
s3://amazon-eks/1.18.9/2020-11-02/
s3://amazon-eks/1.17.12/2020-11-02/
s3://amazon-eks/1.16.15/2020-11-02/
s3://amazon-eks/1.15.12/2020-11-02/

AMI details:

* kernel: 5.4.144-69.257.amzn2 (1.19 and above), (1.18 and below)
* dockerd: 19.03.13-ce
* containerd: 1.4.6
* runc: 1.0.0.amzn2
* cuda: 460.73.01
* nvidia-container-runtime-hook: 460.73.01
* SSM agent: 3.0.1124.0

Notable changes:
* This release includes the patch for the CA to handle Let's Encrypt Certificate Expiry
* Updating default [containerd socket path](https://github.com/awslabs/amazon-eks-ami/commit/9576786266df8bee08e97c1c7f2d0e2f85752092)

## AMI Release v20210914

* amazon-eks-gpu-node-1.21-v20210914
* amazon-eks-gpu-node-1.20-v20210914
* amazon-eks-gpu-node-1.19-v20210914
* amazon-eks-gpu-node-1.18-v20210914
* amazon-eks-gpu-node-1.17-v20210914
* amazon-eks-gpu-node-1.16-v20210914
* amazon-eks-arm64-node-1.21-v20210914
* amazon-eks-arm64-node-1.20-v20210914
* amazon-eks-arm64-node-1.19-v20210914
* amazon-eks-arm64-node-1.18-v20210914
* amazon-eks-arm64-node-1.17-v20210914
* amazon-eks-arm64-node-1.16-v20210914
* amazon-eks-node-1.21-v20210914
* amazon-eks-node-1.20-v20210914
* amazon-eks-node-1.19-v20210914
* amazon-eks-node-1.18-v20210914
* amazon-eks-node-1.17-v20210914
* amazon-eks-node-1.16-v20210914

Notable changes:
Adding support for new ec2 instance types i.e. m6i

## AMI Release v20210830

* amazon-eks-gpu-node-1.21-v20210830
* amazon-eks-gpu-node-1.20-v20210830
* amazon-eks-gpu-node-1.19-v20210830
* amazon-eks-gpu-node-1.18-v20210830
* amazon-eks-gpu-node-1.17-v20210830
* amazon-eks-gpu-node-1.16-v20210830
* amazon-eks-arm64-node-1.21-v20210830
* amazon-eks-arm64-node-1.20-v20210830
* amazon-eks-arm64-node-1.19-v20210830
* amazon-eks-arm64-node-1.18-v20210830
* amazon-eks-arm64-node-1.17-v20210830
* amazon-eks-arm64-node-1.16-v20210830
* amazon-eks-node-1.21-v20210830
* amazon-eks-node-1.20-v20210830
* amazon-eks-node-1.19-v20210830
* amazon-eks-node-1.18-v20210830
* amazon-eks-node-1.17-v20210830
* amazon-eks-node-1.16-v20210830

Notable changes:

* Upgrade kubelet version for 1.17 and 1.20
  * 1.17.12 -> 1.17.17
  * 1.20.4 -> 1.20.7

## AMI Release v20210826

* amazon-eks-gpu-node-1.21-v20210826
* amazon-eks-gpu-node-1.20-v20210826
* amazon-eks-gpu-node-1.19-v20210826
* amazon-eks-gpu-node-1.18-v20210826
* amazon-eks-gpu-node-1.17-v20210826
* amazon-eks-gpu-node-1.16-v20210826
* amazon-eks-gpu-node-1.15-v20210826
* amazon-eks-arm64-node-1.21-v20210826
* amazon-eks-arm64-node-1.20-v20210826
* amazon-eks-arm64-node-1.19-v20210826
* amazon-eks-arm64-node-1.18-v20210826
* amazon-eks-arm64-node-1.17-v20210826
* amazon-eks-arm64-node-1.16-v20210826
* amazon-eks-arm64-node-1.15-v20210826
* amazon-eks-node-1.21-v20210826
* amazon-eks-node-1.20-v20210826
* amazon-eks-node-1.19-v20210826
* amazon-eks-node-1.18-v20210826
* amazon-eks-node-1.17-v20210826
* amazon-eks-node-1.16-v20210826
* amazon-eks-node-1.15-v20210826

Notable changes:

* Fix to reduce permissions of `pull-sandbox-image.sh` [c78bb6b](https://github.com/awslabs/amazon-eks-ami/commit/c78bb6bac21e9323f1f9c57568ece93c1f1d507b)


## AMI Release v20210813

* amazon-eks-gpu-node-1.21-v20210813
* amazon-eks-gpu-node-1.20-v20210813
* amazon-eks-gpu-node-1.19-v20210813
* amazon-eks-gpu-node-1.18-v20210813
* amazon-eks-gpu-node-1.17-v20210813
* amazon-eks-gpu-node-1.16-v20210813
* amazon-eks-gpu-node-1.15-v20210813
* amazon-eks-arm64-node-1.21-v20210813
* amazon-eks-arm64-node-1.20-v20210813
* amazon-eks-arm64-node-1.19-v20210813
* amazon-eks-arm64-node-1.18-v20210813
* amazon-eks-arm64-node-1.17-v20210813
* amazon-eks-arm64-node-1.16-v20210813
* amazon-eks-arm64-node-1.15-v20210813
* amazon-eks-node-1.21-v20210813
* amazon-eks-node-1.20-v20210813
* amazon-eks-node-1.19-v20210813
* amazon-eks-node-1.18-v20210813
* amazon-eks-node-1.17-v20210813
* amazon-eks-node-1.16-v20210813
* amazon-eks-node-1.15-v20210813

Notable changes:
* Contains fix for sanbox-image issue with containerd in Gov-cloud and CN regions.
* Updating to 1.18.20 and 1.19.13 kubernetes version.

## AMI Release v20210722

* amazon-eks-gpu-node-1.21-v20210722
* amazon-eks-gpu-node-1.20-v20210722
* amazon-eks-gpu-node-1.19-v20210722
* amazon-eks-gpu-node-1.18-v20210722
* amazon-eks-gpu-node-1.17-v20210722
* amazon-eks-gpu-node-1.16-v20210722
* amazon-eks-gpu-node-1.15-v20210722
* amazon-eks-arm64-node-1.21-v20210722
* amazon-eks-arm64-node-1.20-v20210722
* amazon-eks-arm64-node-1.19-v20210722
* amazon-eks-arm64-node-1.18-v20210722
* amazon-eks-arm64-node-1.17-v20210722
* amazon-eks-arm64-node-1.16-v20210722
* amazon-eks-arm64-node-1.15-v20210722
* amazon-eks-node-1.21-v20210722
* amazon-eks-node-1.20-v20210722
* amazon-eks-node-1.19-v20210722
* amazon-eks-node-1.18-v20210722
* amazon-eks-node-1.17-v20210722
* amazon-eks-node-1.16-v20210722
* amazon-eks-node-1.15-v20210722

Notable changes:
* This release includes the security patch for the [kernel](https://alas.aws.amazon.com/ALAS-2021-1524.html), for CVE-2021-33909.

## AMI Release v20210720

* amazon-eks-gpu-node-1.21-v20210720
* amazon-eks-gpu-node-1.20-v20210720
* amazon-eks-gpu-node-1.19-v20210720
* amazon-eks-gpu-node-1.18-v20210720
* amazon-eks-gpu-node-1.17-v20210720
* amazon-eks-gpu-node-1.16-v20210720
* amazon-eks-gpu-node-1.15-v20210720
* amazon-eks-arm64-node-1.21-v20210720
* amazon-eks-arm64-node-1.20-v20210720
* amazon-eks-arm64-node-1.19-v20210720
* amazon-eks-arm64-node-1.18-v20210720
* amazon-eks-arm64-node-1.17-v20210720
* amazon-eks-arm64-node-1.16-v20210720
* amazon-eks-arm64-node-1.15-v20210720
* amazon-eks-node-1.21-v20210720
* amazon-eks-node-1.20-v20210720
* amazon-eks-node-1.19-v20210720
* amazon-eks-node-1.18-v20210720
* amazon-eks-node-1.17-v20210720
* amazon-eks-node-1.16-v20210720
* amazon-eks-node-1.15-v20210720

EKS AMI release for Kubernetes version 1.21 (1.21 AMIs for GPU and ARM in us-gov-west-1 and us-gov-east-1 are included in this release)
* Note: The containerd has patch for CVE-2-21-32760

Containerd runtime support
The EKS Optimized Amazon Linux 2 AMI now contains a bootstrap (https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh) flag --container-runtime to optionally enable the containerd runtime. This flag is available in all supported Kubernetes versions of the AMI. This change is to get ahead of the removal of Docker as a supported runtime in Kubernetes (more details here (https://kubernetes.io/blog/2020/12/02/dockershim-faq/)). Feedback is appreciated.

FIPS Kernel Panic issue on 5.4.X is fixed - https://github.com/awslabs/amazon-eks-ami/issues/632

## AMI Release v20210716

* amazon-eks-gpu-node-1.21-v20210716
* amazon-eks-gpu-node-1.20-v20210716
* amazon-eks-gpu-node-1.19-v20210716
* amazon-eks-gpu-node-1.18-v20210716
* amazon-eks-gpu-node-1.17-v20210716
* amazon-eks-gpu-node-1.16-v20210716
* amazon-eks-gpu-node-1.15-v20210716
* amazon-eks-arm64-node-1.21-v20210716
* amazon-eks-arm64-node-1.20-v20210716
* amazon-eks-arm64-node-1.19-v20210716
* amazon-eks-arm64-node-1.18-v20210716
* amazon-eks-arm64-node-1.17-v20210716
* amazon-eks-arm64-node-1.16-v20210716
* amazon-eks-arm64-node-1.15-v20210716
* amazon-eks-node-1.21-v20210716
* amazon-eks-node-1.20-v20210716
* amazon-eks-node-1.19-v20210716
* amazon-eks-node-1.18-v20210716
* amazon-eks-node-1.17-v20210716
* amazon-eks-node-1.16-v20210716
* amazon-eks-node-1.15-v20210716

EKS AMI release for Kubernetes version 1.21 (1.21 AMIs for GPU and ARM in us-gov-west-1 and us-gov-east-1 aren't a part of this release)
* Note: The containerd has patch for CVE-2-21-32760

Containerd runtime support
The EKS Optimized Amazon Linux 2 AMI now contains a bootstrap (https://github.com/awslabs/amazon-eks-ami/blob/master/files/bootstrap.sh) flag --container-runtime to optionally enable the containerd runtime. This flag is available in all supported Kubernetes versions of the AMI. This change is to get ahead of the removal of Docker as a supported runtime in Kubernetes (more details here (https://kubernetes.io/blog/2020/12/02/dockershim-faq/)). Feedback is appreciated.

FIPS Kernel Panic issue on 5.4.X is fixed - https://github.com/awslabs/amazon-eks-ami/issues/632

## AMI Release v20210628
* amazon-eks-gpu-node-1.20-v20210628
* amazon-eks-gpu-node-1.19-v20210628
* amazon-eks-gpu-node-1.18-v20210628
* amazon-eks-gpu-node-1.17-v20210628
* amazon-eks-gpu-node-1.16-v20210628
* amazon-eks-gpu-node-1.15-v20210628
* amazon-eks-arm64-node-1.20-v20210628
* amazon-eks-arm64-node-1.19-v20210628
* amazon-eks-arm64-node-1.18-v20210628
* amazon-eks-arm64-node-1.17-v20210628
* amazon-eks-arm64-node-1.16-v20210628
* amazon-eks-arm64-node-1.15-v20210628
* amazon-eks-node-1.20-v20210628
* amazon-eks-node-1.19-v20210628
* amazon-eks-node-1.18-v20210628
* amazon-eks-node-1.17-v20210628
* amazon-eks-node-1.16-v20210628
* amazon-eks-node-1.15-v20210628

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.20.4/2021-04-12/
* s3://amazon-eks/1.19.6/2021-01-05/
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

AMI details:
* kernel: 5.4.117-58.216.amzn2 (1.19 and above), 4.14.232-177.418.amzn2 (1.18 and below)
* dockerd: 19.03.13ce
* containerd: 1.4.1
* runc: 1.0.0-rc93
* cuda: 460.73.01
* nvidia-container-runtime-hook: 460.73.01
* SSM agent: 3.0.1295.0

Notable changes:

Includes the latest security patches for [systemd](https://alas.aws.amazon.com/AL2/ALAS-2021-1647.html), [python3](https://alas.aws.amazon.com/AL2/ALAS-2021-1670.html) and others.

## AMI Release v20210621
* amazon-eks-gpu-node-1.20-v20210621
* amazon-eks-gpu-node-1.19-v20210621
* amazon-eks-gpu-node-1.18-v20210621
* amazon-eks-gpu-node-1.17-v20210621
* amazon-eks-gpu-node-1.16-v20210621
* amazon-eks-gpu-node-1.15-v20210621
* amazon-eks-arm64-node-1.20-v20210621
* amazon-eks-arm64-node-1.19-v20210621
* amazon-eks-arm64-node-1.18-v20210621
* amazon-eks-arm64-node-1.17-v20210621
* amazon-eks-arm64-node-1.16-v20210621
* amazon-eks-arm64-node-1.15-v20210621
* amazon-eks-node-1.20-v20210621
* amazon-eks-node-1.19-v20210621
* amazon-eks-node-1.18-v20210621
* amazon-eks-node-1.17-v20210621
* amazon-eks-node-1.16-v20210621
* amazon-eks-node-1.15-v20210621

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.20.4/2021-04-12/
* s3://amazon-eks/1.19.6/2021-01-05/
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

AMI details:
* kernel: 5.4.117-58.216.amzn2.x86_64 (1.19 and above), 4.14.232-176.381.amzn2.x86_64 (1.18 and below)
* dockerd: 19.03.13-ce
* containerd: 1.4.1
* runc: 1.0.0-rc93
* cuda: 460.73.01
* nvidia-container-runtime-hook: 1.4.0
* SSM agent: 3.0.1295.0

Notable changes:
* The SSM Agent will now be automatically installed

## AMI Release v20210526
* amazon-eks-gpu-node-1.20-v20210526
* amazon-eks-gpu-node-1.19-v20210526
* amazon-eks-gpu-node-1.18-v20210526
* amazon-eks-gpu-node-1.17-v20210526
* amazon-eks-gpu-node-1.16-v20210526
* amazon-eks-gpu-node-1.15-v20210526
* amazon-eks-arm64-node-1.20-v20210526
* amazon-eks-arm64-node-1.19-v20210526
* amazon-eks-arm64-node-1.18-v20210526
* amazon-eks-arm64-node-1.17-v20210526
* amazon-eks-arm64-node-1.16-v20210526
* amazon-eks-arm64-node-1.15-v20210526
* amazon-eks-node-1.20-v20210526
* amazon-eks-node-1.19-v20210526
* amazon-eks-node-1.18-v20210526
* amazon-eks-node-1.17-v20210526
* amazon-eks-node-1.16-v20210526
* amazon-eks-node-1.15-v20210526

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.20.4/2021-04-12/
* s3://amazon-eks/1.19.6/2021-01-05/
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

AMI details:
* kernel: 5.4.117-58.216.amzn2.x86_64 (1.19 and above), 4.14.232-176.381.amzn2.x86_64 (1.18 and below)
* dockerd: 19.03.13-ce
* containerd: 1.4.1
* runc: 1.0.0-rc93
* cuda: 460.73.01
* nvidia-container-runtime-hook: 1.4.0


Notable changes:
* [CVE-2021-25215](https://access.redhat.com/security/cve/CVE-2021-25215) patch
* kenel patch for following CVEs: [CVE-2021-31829](https://access.redhat.com/security/cve/CVE-2021-31829), [CVE-2021-23133](https://access.redhat.com/security/cve/CVE-2021-23133), [CVE-2020-29374](https://access.redhat.com/security/cve/CVE-2020-29374)

## AMI Release v20210519
* amazon-eks-gpu-node-1.20-v20210519
* amazon-eks-gpu-node-1.19-v20210519
* amazon-eks-gpu-node-1.18-v20210519
* amazon-eks-gpu-node-1.17-v20210519
* amazon-eks-gpu-node-1.16-v20210519
* amazon-eks-gpu-node-1.15-v20210519
* amazon-eks-arm64-node-1.20-v20210519
* amazon-eks-arm64-node-1.19-v20210519
* amazon-eks-arm64-node-1.18-v20210519
* amazon-eks-arm64-node-1.17-v20210519
* amazon-eks-arm64-node-1.16-v20210519
* amazon-eks-arm64-node-1.15-v20210519
* amazon-eks-node-1.20-v20210519
* amazon-eks-node-1.19-v20210519
* amazon-eks-node-1.18-v20210519
* amazon-eks-node-1.17-v20210519
* amazon-eks-node-1.16-v20210519
* amazon-eks-node-1.15-v20210519

Binaries used to build these AMIs are published:
* s3://amazon-eks/1.20.4/2021-04-12/
* s3://amazon-eks/1.19.6/2021-01-05/
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

AMI details:
* kernel: 5.4.110-54.189.amzn2.x86_64 (1.19 and above), 4.14.231-173.361.amzn2.x86_64 (1.18 and below)
* dockerd: 19.03.13-ce
* containerd: 1.4.1
* runc: 1.0.0-rc93
* cuda: 460.73.01
* nvidia-container-runtime-hook: 1.4.0


Notable changes:
* `runc` version upgrade to `rc93` for GPU AMIs
* [fix](https://github.com/opencontainers/runc/pull/2871) for [#2530](https://github.com/opencontainers/runc/issues/2530) backported to `rc93` for GPU AMIs
* [`runc` CVE 2021-30465](https://github.com/opencontainers/runc/security/advisories/GHSA-c3xm-pvg7-gh7r) patch backported to `rc93` for GPU AMIs

## AMI Release v20210518

* amazon-eks-gpu-node-1.19-v20210518
* amazon-eks-gpu-node-1.18-v20210518
* amazon-eks-gpu-node-1.17-v20210518
* amazon-eks-gpu-node-1.16-v20210518
* amazon-eks-gpu-node-1.15-v20210518
* amazon-eks-arm64-node-1.19-v20210518
* amazon-eks-arm64-node-1.18-v20210518
* amazon-eks-arm64-node-1.17-v20210518
* amazon-eks-arm64-node-1.16-v20210518
* amazon-eks-arm64-node-1.15-v20210518
* amazon-eks-node-1.19-v20210518
* amazon-eks-node-1.18-v20210518
* amazon-eks-node-1.17-v20210518
* amazon-eks-node-1.16-v20210518
* amazon-eks-node-1.15-v20210518

Binaries used to build these AMIs are published:

* s3://amazon-eks/1.20.4/2021-04-12/
* s3://amazon-eks/1.19.6/2021-01-05/
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes:
* `runc` version upgrade to `rc93`
* [fix](https://github.com/opencontainers/runc/pull/2871) for [#2530](https://github.com/opencontainers/runc/issues/2530) backported to `rc93`
* [`runc` CVE 2021-30465](https://github.com/opencontainers/runc/security/advisories/GHSA-c3xm-pvg7-gh7r) patch backported to `rc93`

## AMI Release v20210512

* amazon-eks-gpu-node-1.19-v20210512
* amazon-eks-gpu-node-1.18-v20210512
* amazon-eks-gpu-node-1.17-v20210512
* amazon-eks-gpu-node-1.16-v20210512
* amazon-eks-gpu-node-1.15-v20210512
* amazon-eks-arm64-node-1.19-v20210512
* amazon-eks-arm64-node-1.18-v20210512
* amazon-eks-arm64-node-1.17-v20210512
* amazon-eks-arm64-node-1.16-v20210512
* amazon-eks-arm64-node-1.15-v20210512
* amazon-eks-node-1.19-v20210512
* amazon-eks-node-1.18-v20210512
* amazon-eks-node-1.17-v20210512
* amazon-eks-node-1.16-v20210512
* amazon-eks-node-1.15-v20210512

Binaries used to build these AMIs are published:

* s3://amazon-eks/1.20.4/2021-04-12/
* s3://amazon-eks/1.19.6/2021-01-05/
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes:
* Release 1.20 AMIs

## AMI Release v20210504

* amazon-eks-gpu-node-1.19-v20210504
* amazon-eks-gpu-node-1.18-v20210504
* amazon-eks-gpu-node-1.17-v20210504
* amazon-eks-gpu-node-1.16-v20210504
* amazon-eks-gpu-node-1.15-v20210504
* amazon-eks-arm64-node-1.19-v20210504
* amazon-eks-arm64-node-1.18-v20210504
* amazon-eks-arm64-node-1.17-v20210504
* amazon-eks-arm64-node-1.16-v20210504
* amazon-eks-arm64-node-1.15-v20210504
* amazon-eks-node-1.19-v20210504
* amazon-eks-node-1.18-v20210504
* amazon-eks-node-1.17-v20210504
* amazon-eks-node-1.16-v20210504
* amazon-eks-node-1.15-v20210504

Binaries used to build these AMIs are published:

s3://amazon-eks/1.19.6/2021-01-05/
s3://amazon-eks/1.18.9/2020-11-02/
s3://amazon-eks/1.17.12/2020-11-02/
s3://amazon-eks/1.16.15/2020-11-02/
s3://amazon-eks/1.15.12/2020-11-02/

Notable changes:

* Update Kernel (1.19: 5.4.110-54.189.amzn2.x86_64, 1.18 and below: 4.14.231-173.361.amzn2.x86_64) to address a vulnerability. More information available in [ALAS-2021-1634](https://alas.aws.amazon.com/AL2/ALAS-2021-1634.html)
* Update Nvidia and Cuda drivers to v460.73.01

## AMI Release v20210501

* amazon-eks-gpu-node-1.19-v20210501
* amazon-eks-gpu-node-1.18-v20210501
* amazon-eks-gpu-node-1.17-v20210501
* amazon-eks-gpu-node-1.16-v20210501
* amazon-eks-gpu-node-1.15-v20210501
* amazon-eks-arm64-node-1.19-v20210501
* amazon-eks-arm64-node-1.18-v20210501
* amazon-eks-arm64-node-1.17-v20210501
* amazon-eks-arm64-node-1.16-v20210501
* amazon-eks-arm64-node-1.15-v20210501
* amazon-eks-node-1.19-v20210501
* amazon-eks-node-1.18-v20210501
* amazon-eks-node-1.17-v20210501
* amazon-eks-node-1.16-v20210501
* amazon-eks-node-1.15-v20210501

Binaries used to build these AMIs are published:

s3://amazon-eks/1.19.6/2021-01-05/
s3://amazon-eks/1.18.9/2020-11-02/
s3://amazon-eks/1.17.12/2020-11-02/
s3://amazon-eks/1.16.15/2020-11-02/
s3://amazon-eks/1.15.12/2020-11-02/

Notable changes:

* Patches for Linux kernel 4.14, used by AMIs with Kubernetes v1.18 and below (CVE ALAS2-2021-1627)
* Patches for Linux kernel 5.4, used by AMIs with Kubernetes v1.19 to fix a race condition with Conntrack.



### AMI Release v20210414

* amazon-eks-gpu-node-1.19-v20210414
* amazon-eks-gpu-node-1.18-v20210414
* amazon-eks-gpu-node-1.17-v20210414
* amazon-eks-gpu-node-1.16-v20210414
* amazon-eks-gpu-node-1.15-v20210414
* amazon-eks-arm64-node-1.19-v20210414
* amazon-eks-arm64-node-1.18-v20210414
* amazon-eks-arm64-node-1.17-v20210414
* amazon-eks-arm64-node-1.16-v20210414
* amazon-eks-arm64-node-1.15-v20210414
* amazon-eks-node-1.19-v20210414
* amazon-eks-node-1.18-v20210414
* amazon-eks-node-1.17-v20210414
* amazon-eks-node-1.16-v20210414
* amazon-eks-node-1.15-v20210414

Binaries used to build these AMIs are published:
s3://amazon-eks/1.19.6/2021-01-05/
s3://amazon-eks/1.18.9/2020-11-02/
s3://amazon-eks/1.17.12/2020-11-02/
s3://amazon-eks/1.16.15/2020-11-02/
s3://amazon-eks/1.15.12/2020-11-02/

Notable changes:
A regression was introduced for 1.19 AMI in the last release as a result of runc version update to `1.0.0-rc93` causing nodes to flap between `Ready` and `NotReady`, more details [#648](https://github.com/awslabs/amazon-eks-ami/issues/648). We are reverting the runc version back to 1.0.0-rc92.


### AMI Release v20210329

* amazon-eks-gpu-node-1.19-v20210329
* amazon-eks-gpu-node-1.18-v20210329
* amazon-eks-gpu-node-1.17-v20210329
* amazon-eks-gpu-node-1.16-v20210329
* amazon-eks-gpu-node-1.15-v20210329
* amazon-eks-arm64-node-1.19-v20210329
* amazon-eks-arm64-node-1.18-v20210329
* amazon-eks-arm64-node-1.17-v20210329
* amazon-eks-arm64-node-1.16-v20210329
* amazon-eks-arm64-node-1.15-v20210329
* amazon-eks-node-1.19-v20210329
* amazon-eks-node-1.18-v20210329
* amazon-eks-node-1.17-v20210329
* amazon-eks-node-1.16-v20210329
* amazon-eks-node-1.15-v20210329

Binaries used to build these AMIs are published:
s3://amazon-eks/1.19.6/2021-01-05/
s3://amazon-eks/1.18.9/2020-11-02/
s3://amazon-eks/1.17.12/2020-11-02/
s3://amazon-eks/1.16.15/2020-11-02/
s3://amazon-eks/1.15.12/2020-11-02/

Notable changes:
A regression was introduced to the 4.14 Amazon Linux Kernel where I/O could slow significantly after running some workloads for a long period of time (observations point to between 4 hours and several days). This release contains the Kernel patch which fixes the above issue.




### AMI Release v20210322

* amazon-eks-gpu-node-1.19-v20210322
* amazon-eks-gpu-node-1.18-v20210322
* amazon-eks-gpu-node-1.17-v20210322
* amazon-eks-gpu-node-1.16-v20210322
* amazon-eks-gpu-node-1.15-v20210322
* amazon-eks-arm64-node-1.19-v20210322
* amazon-eks-arm64-node-1.18-v20210322
* amazon-eks-arm64-node-1.17-v20210322
* amazon-eks-arm64-node-1.16-v20210322
* amazon-eks-arm64-node-1.15-v20210322
* amazon-eks-node-1.19-v20210322
* amazon-eks-node-1.18-v20210322
* amazon-eks-node-1.17-v20210322
* amazon-eks-node-1.16-v20210322
* amazon-eks-node-1.15-v20210322

Binaries used to build these AMIs are published :
s3://amazon-eks/1.19.6/2021-01-05/
s3://amazon-eks/1.18.9/2020-11-02/
s3://amazon-eks/1.17.12/2020-11-02/
s3://amazon-eks/1.16.15/2020-11-02/
s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
- Updates Nvidia drivers to version `460.32.03`
- patch for CVE-2021-27363, CVE-2021-27364, CVE-2021-27365
- set kubelet log verbosity to 2

### AMI Release v20210310
* amazon-eks-gpu-node-1.19-v20210310
* amazon-eks-gpu-node-1.18-v20210310
* amazon-eks-gpu-node-1.17-v20210310
* amazon-eks-gpu-node-1.16-v20210310
* amazon-eks-gpu-node-1.15-v20210310
* amazon-eks-arm64-node-1.19-v20210310
* amazon-eks-arm64-node-1.18-v20210310
* amazon-eks-arm64-node-1.17-v20210310
* amazon-eks-arm64-node-1.16-v20210310
* amazon-eks-arm64-node-1.15-v20210310
* amazon-eks-node-1.19-v20210310
* amazon-eks-node-1.18-v20210309
* amazon-eks-node-1.17-v20210309
* amazon-eks-node-1.16-v20210309
* amazon-eks-node-1.15-v20210309

Binaries used to build these AMIs are published :
s3://amazon-eks/1.19.6/2021-01-05/
s3://amazon-eks/1.18.9/2020-11-02/
s3://amazon-eks/1.17.12/2020-11-02/
s3://amazon-eks/1.16.15/2020-11-02/
s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
- Updates Nvidia drivers to version `460.27.04`
- GPU AMIs no longer uses `daemon.json` defined in https://github.com/awslabs/amazon-eks-ami/blob/master/files/docker-daemon.json

### AMI Release v20210302

**GPU AMIs in this release are not compatible with any eksctl version after [eksctl 0.34.0](https://github.com/weaveworks/eksctl/releases/tag/0.34.0)**

* amazon-eks-gpu-node-1.19-v20210302
* amazon-eks-gpu-node-1.18-v20210302
* amazon-eks-gpu-node-1.17-v20210302
* amazon-eks-gpu-node-1.16-v20210302
* amazon-eks-gpu-node-1.15-v20210302
* amazon-eks-arm64-node-1.19-v20210302
* amazon-eks-arm64-node-1.18-v20210302
* amazon-eks-arm64-node-1.17-v20210302
* amazon-eks-arm64-node-1.16-v20210302
* amazon-eks-arm64-node-1.15-v20210302
* amazon-eks-node-1.19-v20210302
* amazon-eks-node-1.18-v20210302
* amazon-eks-node-1.17-v20210302
* amazon-eks-node-1.16-v20210302
* amazon-eks-node-1.15-v20210302

Binaries used to build these AMIs are published:
- s3://amazon-eks/1.19.6/2021-01-05/
- s3://amazon-eks/1.18.9/2020-11-02/
- s3://amazon-eks/1.17.12/2020-11-02/
- s3://amazon-eks/1.16.15/2020-11-02/
- s3://amazon-eks/1.15.12/2020-11-02/

Notable changes:
- files/bootstrap.sh: ensure /etc/docker exists before writing to it (#611)
- GPU AMIs now use docker `daemon.json` defined in https://github.com/awslabs/amazon-eks-ami/blob/master/files/docker-daemon.json
- Patch for CVE-2021-3177
- check that nvidia-smi is configured correctly before updating GPU clocks (#613)
- Fix Makefile indentation for 1.19 (#616)
- Increase fs.inotify.max_user_instances to 8192 from the default of 128 (#614)
- use dynamic lookup of docker gid (#622)
- bump docker version to 19.03.13ce-1 (#624) 

### AMI Release v20210208
* amazon-eks-gpu-node-1.19-v20210208
* amazon-eks-gpu-node-1.18-v20210208
* amazon-eks-gpu-node-1.17-v20210208
* amazon-eks-gpu-node-1.16-v20210208
* amazon-eks-gpu-node-1.15-v20210208
* amazon-eks-arm64-node-1.19-v20210208
* amazon-eks-arm64-node-1.18-v20210208
* amazon-eks-arm64-node-1.17-v20210208
* amazon-eks-arm64-node-1.16-v20210208
* amazon-eks-arm64-node-1.15-v20210208
* amazon-eks-node-1.19-v20210208
* amazon-eks-node-1.18-v20210208
* amazon-eks-node-1.17-v20210208
* amazon-eks-node-1.16-v20210208
* amazon-eks-node-1.15-v20210208

Binaries used to build these AMIs are published :
* s3://amazon-eks/1.19.6/2021-01-05/
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
* Kubernetes versions 1.19+ will now use the 5.4 Linux kernel
* Patch for [ALAS-2021-1588](https://alas.aws.amazon.com/AL2/ALAS-2021-1588.html)

### AMI Release v20210125
* amazon-eks-gpu-node-1.18-v20210125
* amazon-eks-gpu-node-1.17-v20210125
* amazon-eks-gpu-node-1.16-v20210125
* amazon-eks-gpu-node-1.15-v20210125
* amazon-eks-arm64-node-1.18-v20210125
* amazon-eks-arm64-node-1.17-v20210125
* amazon-eks-arm64-node-1.16-v20210125
* amazon-eks-arm64-node-1.15-v20210125
* amazon-eks-node-1.18-v20210125
* amazon-eks-node-1.17-v20210125
* amazon-eks-node-1.16-v20210125
* amazon-eks-node-1.15-v20210125

Binaries used to build these AMIs are published :
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
* ARM AMIs built with m6g.large instance type (#601) 
* Add Support for c6gn instance type (#597)
* Patch for CVE-2021-3156 (https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2021-3156)

### AMI Release v20210112
* amazon-eks-gpu-node-1.18-v20210112
* amazon-eks-gpu-node-1.17-v20210112
* amazon-eks-gpu-node-1.16-v20210112
* amazon-eks-gpu-node-1.15-v20210112
* amazon-eks-arm64-node-1.18-v20210112
* amazon-eks-arm64-node-1.17-v20210112
* amazon-eks-arm64-node-1.16-v20210112
* amazon-eks-arm64-node-1.15-v20210112
* amazon-eks-node-1.18-v20210112
* amazon-eks-node-1.17-v20210112
* amazon-eks-node-1.16-v20210112
* amazon-eks-node-1.15-v20210112

Binaries used to build these AMIs are published :
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
* Update ulimit for memlock to unlimited
* Update ulimit for max_user_watches and max_file_count
* Fix position of sonobuoy e2e registry config check (#590)
* Update Makefile to support sonobuoy e2e registry config override (#588)
* fix syntax error in install script (#582) introduced by #522
* Feature flag the cleanup of the image (#522)
* Add iptables rule count to log collector
* GPU Boost clock setup for performance improvement (#573)
* add support for sonobuoy e2e registry overrides (#585) for MVP
* ensure kubelet.service.d directory exists (#519)
* (bootstrap): document pause container parameters (#556)
* add SIGKILL to RestartForceExitStatus (#554)
* fix containerd_version typo in Makefile (#584)
* Update systemd to always restart kubelet to support dynamic kubelet configuration (#578)
* Add missing instance types (#580)

### AMI Release v20201211
* amazon-eks-gpu-node-1.18-v20201211
* amazon-eks-gpu-node-1.17-v20201211
* amazon-eks-gpu-node-1.16-v20201211
* amazon-eks-gpu-node-1.15-v20201211
* amazon-eks-arm64-node-1.18-v20201211
* amazon-eks-arm64-node-1.17-v20201211
* amazon-eks-arm64-node-1.16-v20201211
* amazon-eks-arm64-node-1.15-v20201211
* amazon-eks-node-1.18-v20201211
* amazon-eks-node-1.17-v20201211
* amazon-eks-node-1.16-v20201211
* amazon-eks-node-1.15-v20201211

Binaries used to build these AMIs are published :
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
* Bug fix for the issue with rngd on EKS worker ami that's built with AL2 source ami.
* Bug fix for grub issue introduced by new nvidia driver
* Patch for CVE-2020-1971 (https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2020-1971)

### AMI Release v20201126
* amazon-eks-gpu-node-1.18-v20201126
* amazon-eks-gpu-node-1.17-v20201126
* amazon-eks-gpu-node-1.16-v20201126
* amazon-eks-gpu-node-1.15-v20201126
* amazon-eks-arm64-node-1.18-v20201126
* amazon-eks-arm64-node-1.17-v20201126
* amazon-eks-arm64-node-1.16-v20201126
* amazon-eks-arm64-node-1.15-v20201126
* amazon-eks-node-1.18-v20201126
* amazon-eks-node-1.17-v20201126
* amazon-eks-node-1.16-v20201126
* amazon-eks-node-1.15-v20201126

Binaries used to build these AMIs are published :
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :

* Containerd patch for CVE-2020-15257 (containerd-1.4.1-2)


### AMI Release v20201117
* amazon-eks-gpu-node-1.18-v20201117
* amazon-eks-gpu-node-1.17-v20201117
* amazon-eks-gpu-node-1.16-v20201117
* amazon-eks-gpu-node-1.15-v20201117
* amazon-eks-arm64-node-1.18-v20201117
* amazon-eks-arm64-node-1.17-v20201117
* amazon-eks-arm64-node-1.16-v20201117
* amazon-eks-arm64-node-1.15-v20201117
* amazon-eks-node-1.18-v20201117
* amazon-eks-node-1.17-v20201117
* amazon-eks-node-1.16-v20201117
* amazon-eks-node-1.15-v20201117

Binaries used to build these AMIs are published :
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
* Bug fix [#526](https://github.com/awslabs/amazon-eks-ami/pull/526)
* GPU AMIs - Nvidia driver version update to 450.51.06, cuda version update to 11.0
* Updated kernel version to 4.14.203 and fix for soft lockup issue
* Downgraded containerd version to 1.3.2 to fix pods getting stuck in the Terminating state


### AMI Release v20201112
* amazon-eks-gpu-node-1.18-v20201112
* amazon-eks-gpu-node-1.17-v20201112
* amazon-eks-gpu-node-1.16-v20201112
* amazon-eks-gpu-node-1.15-v20201112
* amazon-eks-arm64-node-1.18-v20201112
* amazon-eks-arm64-node-1.17-v20201112
* amazon-eks-arm64-node-1.16-v20201112
* amazon-eks-arm64-node-1.15-v20201112
* amazon-eks-node-1.18-v20201112
* amazon-eks-node-1.17-v20201112
* amazon-eks-node-1.16-v20201112
* amazon-eks-node-1.15-v20201112

Binaries used to build these AMIs are published :
* s3://amazon-eks/1.18.9/2020-11-02/
* s3://amazon-eks/1.17.12/2020-11-02/
* s3://amazon-eks/1.16.15/2020-11-02/
* s3://amazon-eks/1.15.12/2020-11-02/

Notable changes :
* Bug fix [#526](https://github.com/awslabs/amazon-eks-ami/pull/526)
* GPU AMIs - Nvidia driver version update to 450.51.06, cuda version update to 11.0
* Updated kernel version to 4.14.203 and fix for [soft lockup issue](https://github.com/awslabs/amazon-eks-ami/issues/454)


Note: Previous release information can be found from [release note](https://github.com/awslabs/amazon-eks-ami/releases)


### AMI Release v20190927
* amazon-eks-node-1.14-v20190927
* amazon-eks-gpu-node-1.14-v20190927
* amazon-eks-node-1.13-v20190927
* amazon-eks-gpu-node-1.13-v20190927
* amazon-eks-node-1.12-v20190927
* amazon-eks-gpu-node-1.12-v20190927
* amazon-eks-node-1.11-v20190927
* amazon-eks-gpu-node-1.11-v20190927

Changes:
* 0f11f6c Add G4DN instance family to node group template
* ade31b0 Add support for g4 instance family
* d9147f1 sync nodegroup template to latest available

### AMI Release v20190906
* amazon-eks-node-1.14-v20190906
* amazon-eks-gpu-node-1.14-v20190906
* amazon-eks-node-1.13-v20190906
* amazon-eks-gpu-node-1.13-v20190906
* amazon-eks-node-1.12-v20190906
* amazon-eks-gpu-node-1.12-v20190906
* amazon-eks-node-1.11-v20190906
* amazon-eks-gpu-node-1.11-v20190906

Changes:
* c1ae2f3 Adding new directory and file for 1.14 and above by removing --allow-privileged=true flag (#327)
* 5335ea8 add support for me-south-1 region (#322)
* c4e03c1 Update list of instance types (#320)
* 389f4ba update S3_URL_BASE environment variable in install-worker.sh

Kubernetes Changes:
* Kubelet patches with [HTTP2-cve](https://nvd.nist.gov/vuln/detail/CVE-2019-9512)
* Kubelet patched with fix for https://github.com/kubernetes/kubernetes/issues/78164

### AMI Release v20190814
* amazon-eks-node-1.13-v20190814
* amazon-eks-gpu-node-1.13-v20190814
* amazon-eks-node-1.13-v20190814
* amazon-eks-gpu-node-1.13-v20190814
* amazon-eks-node-1.13-v20190814
* amazon-eks-gpu-node-1.13-v20190814
#### Changes
* 0468404 change the amiName pattern to use minor version (#307)
* 19ff806 2107 allow private ssh when building (#303)
* 2b9b501 add support for ap-east-1 region (#305)
* ccae017 Fix t3a.small limit
* f409acd Add new m5 and r5 instances
* 8bbf269 Add c5.12xlarge and c5.24xlarge instances
* 1f83c10 refactor packer variables
* 41f4dd9 Install ec2-instance-connect
* a40bd46 Added CHANGELOG for v20190701



### amazon-eks-node-1.13-v20190701 | amazon-eks-node-1.12-v20190701 | amazon-eks-node-1.11-v20190701 | amazon-eks-node-1.10-v20190701 | amazon-eks-gpu-node-1.13-v20190701 | amazon-eks-gpu-node-1.12-v20190701 | amazon-eks-gpu-node-1.11-v20190701 | amazon-eks-gpu-node-1.10-v20190701

Note: The AMI no longer contains kubectl. If you rely on kubectl being present, you can download it from the S3 bucket `s3://amazon-eks/`

* ca61cc2 remove kubectl dependency (#295)
* 400dd58 Update eks-log-collector.sh URL on readme
* e4fe057 Moving log collector script to Amazon eks ami repo (#243)
* e8b50ba add changelog for 20190614

### amazon-eks-node-1.13-v20190614 | amazon-eks-node-1.12-v20190614 | amazon-eks-node-1.11-v20190614 | amazon-eks-node-1.10-v20190614 | amazon-eks-gpu-node-1.13-v20190614 | amazon-eks-gpu-node-1.12-v20190614 | amazon-eks-gpu-node-1.11-v20190614 | amazon-eks-gpu-node-1.10-v20190614

Security Note: These AMIs contain OS(AmazonLinux2) patched for [CVE-2019-11477, CVE-2019-11478, CVE-2019-11479](https://aws.amazon.com/security/security-bulletins/AWS-2019-005/)

Note: This release also publishes first set of worker AMIs for EKS 1.13 launch

* b1726c1 Fix issue with 1.10 build
* f2525cb Change clocksource only if using xen
* 16bd031 files/kubelet: specify "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
* 88ca2ac Retry if AWS API returns None (#274)
* 6f3354a Add a docker daemon restart after custom daemon.json
* 92e33a8 Making tsc the clock source (#272)
* eccfa3a Use kubernetes minor version to choose kubelet config
* 32d2ac4 Update nodegroup values
* 5b99e15 Add new instance types
* b061339 Restrict kubelet to only use TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256 for tls cipher suites
* fe39deb add build spec for amazon's internal build process
* b5a78b9 add options to configure packer/aws binary
* ac67f2a Allow custom config for docker daemon
* ca5559a Add ARM support
* 2caf69b Updated bug-report.md and question.md instructions to currently existing release info location - /etc/eks/release (#242)

### amazon-eks-node-1.12-v20190329 | amazon-eks-node-1.11-v20190329 | amazon-eks-node-1.10-v20190329

Security Note: These AMIs contain builds of kubectl & CNI patched for [CVE-2019-1002101](https://aws.amazon.com/security/security-bulletins/AWS-2019-003/) and [CVE-2019-9946](https://aws.amazon.com/security/security-bulletins/AWS-2019-003/)

Note: This release publishes first set of worker AMIs for EKS 1.12 launch

* 77ae68a Correct version numbers in Changelog
* 3e09987 Bump CNI plugin default value
* fb0c393 Update eni-max-pods.txt (#231)
* a809997 Update README with new worker AMIs published on 2019-03-27
* a038aae Added 1.12 build in Makefile (#208)
* 38eb8a8 Fixed search for 10.x CIDR range
* 91ed091 Updated describe-cluster retry/backoff exponential with jitter
* 907df9f Updated the sleep time to seconds from milliseconds
* bc4216c Retry logic for describe cluster API call
* 325f1cc Fixed regex to match 10.x in all cases
* 7df0912 provide region during build
* 086c6a3 Ability to provide custom ami during build
* 6090f20 Updated binaries to latest releases
* 04c520d Create custom kubelet config with TTL-based secret-caching
* e5e5678 Fix downloading binaries from public s3 bucket.
* ae9b7d7 Fix: mac address is returned with trailing slash which breaks CIDR call resulting in false ten range
* 954d8b0 Allow pulling node binaries from private bucket (#175)
* 9f20002 Removed ulimit reduction
* a052b53 changed kube-proxy log rotation from create to copytruncate
* d2c26e8 Switched to RPM install for AWS CLI

### amazon-eks-node-1.11-v20190220 | amazon-eks-node-1.10-v20190220

* c1934bb Made docker install optional
* 0db49b4 Added enable-docker-bridge bootstrap argument
* 5a57ab8 Increase ulimits for docker containers.
* 4cf8ff5 Fix bug causing bootstrap.sh to fail for certain instance types
* 42dfbd7 update docker version to 18.06
* 9ac7eba Clean resolv.conf before snapshotting
* 665c29d Updated changelog to clarify CVE-2019-5736
* 71e5db6 Added security wording to issue templates

### amazon-eks-node-1.11-v20190211 | amazon-eks-node-1.10-v20190211

Security Note: This AMI contains a build of Docker 17.06 that is patched for [CVE-2019-5736](https://aws.amazon.com/security/security-bulletins/AWS-2019-002/)

* 71cd4b0 Updated max-pods for larger instance types
* 28845f9 Allow parallel image pulls
* 5cc7f41 Make it possible to set the DOCKER_VERSION and CNI_* that are used.
* dedf096 Enable live-restore capability in docker daemon
* bed1c54 Replace Path: "/"
* 10c5285 add spacing between remaining components
* 2c60058 remove superflous linebreaks
* e2f7dfa remove superflous lists
* 342e387 consolidate list indentation style
* 9856a22 ensure "Description" fields appear ealier in template
* 06630cf remove default Path
* 2823ba8 remove superflous quotes
* 310215e Property --cgroup-root was not specified
* 7d5a94b Set hairpin mode to "hairpin-veth"
* 5479e95 disable docker0 bridge as it is not used
* 491a913 add bip address from RFC5735 / RFC5737 This will reduce the number of possible conflicts to deploy on existing networks. https://tools.ietf.org/html/rfc5735 https://tools.ietf.org/html/rfc5737
* f8c117f Allow (optional) smaller EBS root volumes with container optimized AMI
* 7f6c8cb Remove trailing and leading lines.
* 01cfe98 Enable syncing of rtc clock in chronyd daemon.

### amazon-eks-node-1.11-v20190109 | amazon-eks-node-1.10-v20190109

* 208c114 Make bootstrap script more readable
* 44d18b7 Addresses #136 - set +e doesn't seem to work. Will return 0 or TEN_RANGE
* 8a1d7c0 Use chrony for time and make sure it is enabled on startup. (#130)
* b46b99a Only restart on failures
* e13d401 Update kubelet.service to be resilient to crashing
* 2f2401a Reversing order to make easier to read
* d1c3e0c Added 1.11 build in Makefile
* 9b8dc41 Fix rendering of the readme file
* 1797887 Update changelog and readme for 1.10 and 1.11 v20181210 worker nodes

### amazon-eks-node-1.11-v20181210 | amazon-eks-node-1.10-v20181210

* 87a2aec Added GitHub issue templates
* 95138f1 Simplified ASG Update parameters
* 31f7d62 Swap order of `sed` and `kubectl config`
* 9ad6e2a Add back the allow-privileged kubelet flag
* 0bf1109 Added serverTLSBootstrap to kubelet config file
* a5492b2 Added node ASG update policy parameters
* b7015a6 Remove deprecated flags that use default values
* d5a6437 Docker config should be owned by root
* c281f32 Adding mkdir command
* 90c5eae Adding simple dockerd config file to rotate logs from containers
* 01090f8 Gracefully handle unknown instance types
* 68e7a62 Added AMI metadata file
* c0110a7 Reverted max-pod updates and instance types
* 90d5209 Correctly select kube-DNS address for secondary CIDR VPC instances
* f7b7f6c Updated kubelet config file location
* 8ff10f2 Updated instance types and eni counts
* 67053cf Modifying kubelet to use config files instead of kubelet flags which are about to deprecate. (#90)
* 6a20fb1 Add max pods information for g3s.xlarge instances
* a16af46 kubelet config files should be owned by root
* f27bc2e Update eni-max-pods.txt

### amazon-eks-node-v25

* 45a12de Fix kube-proxy logrotate (#68)
* 742df5e Change make targets to be .PHONY (#59)
* eb0239f Add NodeSecurityGroup to outputs. (#58)
* 7219545 Only add max-pods for a known instance type (#57)

Note: CNI >= 1.2.1 is required for t3 and r5 instance support.

### amazon-eks-node-v24

* 9cda183 Scrub temporary build-time keypair (#48)
* 9578a45 remove packer key before shutdown (#43)
* cb86cc4 Move source_ami_filter owner to owners (#44)
* 4edeb0c Added /var/log/journal to build  (#40)
* 624bac1 Add support for KMS encryption - disabled by default (#33)
* 586cac2 Add validation for CNI and CNI Plugins downloads - fixes #37 (#38)
* 30617f4 Added back previous CloudFormation version in table (#35)
* b2f9656 Allow communication on TCP:443 from EKS Cluster to Worker nodes (#34)
* 72184ce Adding support New instance types (#31)
* 614d48c Added changelog for 8-21-18 release (#24)

### amazon-eks-node-v23

* ddaaa79 Add ability to modify node root volume size (#20)
* 0c7bd35 Added bootstrap args as a CloudFormation parameter (#23)
* 9736e73 Make sure ntp is installed and enabled (#18)
* 5ef02c9 Updated EKS AMI with bootstrap script (#16)

### eks-worker-v22

* Foreshadow update https://alas.aws.amazon.com/AL2/ALAS-2018-1058.html

### eks-worker-v21

* SegmentSmack update https://alas.aws.amazon.com/AL2/ALAS-2018-1050.html

### eks-worker-v20

* EKS Launch AMI

<!-- git log --pretty=format:"* %h %s" $(git describe --abbrev=0 --tags)..HEAD -->
