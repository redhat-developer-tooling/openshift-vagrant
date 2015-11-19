#!/usr/bin/env bash

# Configures Docker
#
# $1 : Public Red Hat Docker registory host
# $2 : Internal Red Hat Docker registry host
# $3 : Public IP Address
#
# TODO In the final version of the CDK 2, the docker configuration
# should be already done

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

if [ -f /opt/docker_selinux ]; then
  echo "[INFO] Skipping Docker configuration. Already done."
  exit 0;
fi

# Do some SeLinux wodoo
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
sudo setenforce 0
sudo touch /opt/docker_selinux

# Confiugure the Docker registry to get access to the needed repositories
echo "[INFO] Enabling Docker registries $1 and $2"
cat << EOF > /etc/sysconfig/docker
# Configured by Vagrant
DOCKER_CERT_PATH=/etc/docker
INSECURE_REGISTRY='--insecure-registry ${2} --insecure-registry 172.30.0.0/16'
#OPTIONS="--selinux-enabled -H tcp://${3}:2376 -H unix:///var/run/docker.sock --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server-cert.pem --tlskey=/etc/docker/server-key.pem"
OPTIONS="--selinux-enabled -H tcp://10.1.2.2:2376 -H unix:///var/run/docker.sock"
ADD_REGISTRY='--add-registry ${2} --add-registry ${1}'
EOF

systemctl restart docker
