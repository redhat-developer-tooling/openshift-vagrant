#!/usr/bin/env bash

# Configures Docker
#
# TODO In the final version of the CDK 2, the Docker configuration
# should be already working out of the box for all use cases

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
echo "[INFO] Enabling Docker registries"
cat << EOF > /etc/sysconfig/docker
# Configured by Vagrant
DOCKER_CERT_PATH=/etc/docker
OPTIONS="--selinux-enabled -H tcp://0.0.0.0:2376 -H unix:///var/run/docker.sock --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server-cert.pem --tlskey=/etc/docker/server-key.pem --tlsverify"

# INSECURE_REGISTRY and ADD_REGISTRY are used by systemcdl scripts. They are a
# RHEL feature. See http://rhelblog.redhat.com/2015/04/15/understanding-the-changes-to-docker-search-and-docker-pull-in-red-hat-enterprise-linux-7-1/
#
# registry.access.redhat.com - registry from where we pull the OpenShift Enterprise Docker image
# rcm-img-docker01.build.eng.bos.redhat.com:5001 - Deployer and router come from this repo. For now it is needed.
# docker-registry.usersys.redhat.com - allow push/pull from docker-registry.usersys.redhat.com
ADD_REGISTRY='--add-registry registry.access.redhat.com --add-registry docker-registry.usersys.redhat.com --add-registry rcm-img-docker01.build.eng.bos.redhat.com:5001'
INSECURE_REGISTRY='--insecure-registry rcm-img-docker01.build.eng.bos.redhat.com:5001 --insecure-registry 172.30.0.0/16 --insecure-registry docker-registry.usersys.redhat.com'
EOF

systemctl restart docker
