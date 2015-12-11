#!/usr/bin/env bash

# Configures Docker
#
# TODO In the final version of the CDK 2, the Docker configuration
# should be already working out of the box for all use cases

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

# The Docker registry from where we pull the OpenShift Enterprise Docker image
REDHAT_DOCKER_REGISTRY="registry.access.redhat.com"

# TODO - Deployer and router come from this repo. For now it is needed.
REDHAT_INTERNAL_DOCKER_REGISTRY="rcm-img-docker01.build.eng.bos.redhat.com:5001"

if [ -f /opt/docker_selinux ]; then
	echo "[INFO] Skipping Docker configuration. Already done."
	exit 0;
fi

# Do some SeLinux wodoo
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
sudo setenforce 0
sudo touch /opt/docker_selinux

# Confiugure the Docker registry to get access to the needed repositories
echo "[INFO] Enabling Docker registries ${REDHAT_DOCKER_REGISTRY} and ${REDHAT_INTERNAL_DOCKER_REGISTRY}"
cat << EOF > /etc/sysconfig/docker
# Configured by Vagrant
DOCKER_CERT_PATH=/etc/docker
INSECURE_REGISTRY='--insecure-registry ${REDHAT_INTERNAL_DOCKER_REGISTRY} --insecure-registry 172.30.0.0/16'
OPTIONS="--selinux-enabled -H tcp://0.0.0.0:2376 -H unix:///var/run/docker.sock --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server-cert.pem --tlskey=/etc/docker/server-key.pem --tlsverify"
ADD_REGISTRY='--add-registry ${REDHAT_DOCKER_REGISTRY} --add-registry ${REDHAT_INTERNAL_DOCKER_REGISTRY}'
EOF

systemctl restart docker
