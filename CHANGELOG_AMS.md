# Changelog

### 2019-02-14

* Switch to Docker 18.06.

### 2019-01-25

* Switch to chrony instead of NTP.
* Enable live restore for Docker daemon.

### 2018-11-06

* Port kubelet and container-runtime health monitor from GCE K8s image.

### 2018-10-24

* Fix DNS resolution for Ubuntu 18.04.

### 2018-10-18

* Use Ubuntu 18.04 as base AMI instead of Amazon Linux 2.

### 2018-10-17

* Use spot instances to build AMI.
* Install awscli from yum instead of pip.
* Install additional diagnostic tools.
* Setup Docker container log rotation.
