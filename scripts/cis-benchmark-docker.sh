#!/usr/bin/env bash

set -o pipefail
set -o nounset
set -o errexit

# get fragment paths
DOCKER_SERVICE_PATH=$(systemctl show -p FragmentPath docker.service | cut -d"=" -f2)
DOCKER_SOCKET_PATH=$(systemctl show -p FragmentPath docker.socket | cut -d"=" -f2)

# be sure docker folders folders exists
mkdir -p /etc/docker
mkdir -p /etc/sysconfig
mkdir -p /etc/default
mkdir -p /etc/docker
mkdir -p /var/lib/docker
mkdir -p /etc/docker/certs.d/

echo "1.1.1 - ensure the container host has been hardened"
echo "[not scored] - 1.1.1 ensure the container host has been hardened"

echo "1.1.2 - ensure that the version of Docker is up to date"
docker --version

echo "1.2.1 - ensure a separate partition for containers has been created"
grep '/var/lib/docker\s' /proc/mounts

echo "1.2.2 - ensure only trusted users are allowed to control Docker daemon"
getent group docker

echo "1.2.3 - ensure auditing is configured for the Docker daemon"
echo "-w /usr/bin/dockerd -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /usr/bin/docker -k docker" >> /etc/audit/rules.d/docker.rules

echo "1.2.4 - 1.2.12 - ensure auditing is configured for Docker files and directories"
echo "-w /var/lib/docker -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /etc/docker -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /etc/default/docker -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /etc/sysconfig/docker -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /etc/docker/daemon.json -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /usr/bin/containerd -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /usr/bin/docker-containerd -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /usr/bin/runc -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w /usr/bin/docker-runc -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w ${DOCKER_SERVICE_PATH} -k docker" >> /etc/audit/rules.d/docker.rules
echo "-w ${DOCKER_SOCKET_PATH} -k docker" >> /etc/audit/rules.d/docker.rules

echo "2.1 - 2.17 - ensure the docker configuration is secure"
echo "[not scored] - default configuration meets these requirements"

echo "2 - restart the docker daemon"
systemctl daemon-reload && systemctl restart docker

echo "3.1 - 3.2 - ensure that the docker.service file ownership is set to root:root"
chmod -R 0644 ${DOCKER_SERVICE_PATH}
chown -R root:root ${DOCKER_SERVICE_PATH}

chmod -R 0644 ${DOCKER_SOCKET_PATH}
chown -R root:root ${DOCKER_SOCKET_PATH}

echo "3.5 - 3.6 - ensure that the /etc/docker file ownership is set to root:root"
chmod -R 0755 /etc/docker
chown -R root:root /etc/docker

echo "3.7 - 3.8 - Ensure that the /etc/docker file ownership is set to root:root"
chmod -R 0444 /etc/docker/certs.d/
chown -R root:root /etc/docker/certs.d/

echo "3.9 - 3.14 - ensure proper file persions on docker tls certificates"
echo "[not scored] - does not apply because the docker daemon is not exposed outside of the host"

echo "3.15 - ensure that the /var/run/docker.sock file ownership is set to root:docker"
chmod -R 0660 /var/run/docker.sock
chown -R root:docker /var/run/docker.sock

echo "3.17 - 3.18 - ensure that the daemon.json file ownership is set to root:root"
touch /etc/docker/daemon.json
chmod -R 0644 /etc/docker/daemon.json
chown -R root:root /etc/docker/daemon.json

echo "3.19 - 3.21 - ensure that the file ownership is set to root:root"
touch /etc/default/docker
chmod -R 0644 /etc/default/docker
chown -R root:root /etc/default/docker

touch /etc/sysconfig/docker
chmod -R 0644 /etc/sysconfig/docker
chown -R root:root /etc/sysconfig/docker
