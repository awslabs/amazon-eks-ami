# Changelog

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
