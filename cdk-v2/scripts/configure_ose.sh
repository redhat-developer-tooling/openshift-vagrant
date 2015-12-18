#!/usr/bin/env bash

# Prepare, configure and start OpenShift
#
# $1 : Public IP Address
# $2 : Public host name

set -o pipefail
set -o nounset
#set -o xtrace

export ORIGIN_DIR="/var/lib/origin"
export OPENSHIFT_DIR=${ORIGIN_DIR}/openshift.local.config/master
export KUBECONFIG=${OPENSHIFT_DIR}/admin.kubeconfig

# The Docker registry from where we pull the OpenShift Enterprise Docker images
export OSE_IMAGE_NAME=openshift3/ose
export OSE_VERSION=v3.1.0.3
export OPENSHIFT_IMAGE_REGISTRY="rcm-img-docker01.build.eng.bos.redhat.com:5001"
#export OPENSHIFT_IMAGE_REGISTRY="registry.access.redhat.com"

########################################################################
# Helper function to start OpenShift as container
#
# All passed paramters are passed through ti
########################################################################
start_ose() {
	docker run -d --name "ose" --privileged --net=host --pid=host \
    	-v /:/rootfs:ro \
     	-v /var/run:/var/run:rw \
     	-v /sys:/sys:ro \
     	-v /var/lib/docker:/var/lib/docker:rw \
     	-v ${ORIGIN_DIR}/openshift.local.volumes:${ORIGIN_DIR}/openshift.local.volumes:z \
     	-v ${ORIGIN_DIR}/openshift.local.config:${ORIGIN_DIR}/openshift.local.config:z \
     	-v ${ORIGIN_DIR}/openshift.local.etcd:${ORIGIN_DIR}/openshift.local.etcd:z \
     openshift3/ose start "$@"
}

########################################################################
# Helper function to remove existing ose container
########################################################################
rm_ose_container() {
	if docker inspect ose &>/dev/null; then
		docker rm -f -v ose > /dev/null 2>&1
	fi
}

########################################################################
# Helper function to wait for OpenShift config file generation
########################################################################
wait_for_config_files() {
  for i in {1..6}; do
    if [ ! -f ${1} ] || [ ! -f ${2} ]; then
      sleep 5
    else
      break
    fi
  done
  if [ ! -f ${1} ] || [ ! -f ${2} ]; then
    >&2 echo "[ERROR] Unable to create OpenShift config files"
    docker logs ose
    exit 1
  fi
}

########################################################################
# Helper function to wait for OpenShift startup
########################################################################
wait_for_openshift() {
  # Give OpenShift time to start
  for i in {1..6}
  do
    curl -ksSf https://10.0.2.15:8443/api > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      sleep 5
    else
      break
    fi
  done

  # Final check whether OpenShift is running
  curl -ksSf https://10.0.2.15:8443/api > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    >&2 echo "[ERROR] OpenShift failed to start:"
    docker logs ose
    exit 1
  fi
}

########################################################################
# Helper function to pre-pull Docker images
#
# $1 image name
########################################################################
cache_image() {
  docker inspect ${1} &>/dev/null
  if [ ! $? -eq 0 ]; then
    echo "[INFO] Caching Docker image ${1}"
    docker pull ${OPENSHIFT_IMAGE_REGISTRY}/${1}
  fi
}

########################################################################
# Main
########################################################################
# Pre-pull some images in order to speed up the OpenShift out of the box experience
# See also https://github.com/projectatomic/adb-atomic-developer-bundle/issues/160
cache_image openshift3/ose-pod:${OSE_VERSION}
cache_image openshift3/ose-haproxy-router:${OSE_VERSION}
cache_image openshift3/ose-docker-registry:${OSE_VERSION}
cache_image openshift3/ose-sti-builder:${OSE_VERSION}

# Copy OpenShift CLI tools to the VM
binaries=(oc oadm)
for n in ${binaries[@]}; do
	[ -f /usr/bin/${n} ] && continue
	echo "[INFO] Copying the OpenShift '${n}' binary to host /usr/bin/${n}"

	docker run --rm --entrypoint=/bin/cat openshift3/ose /usr/bin/${n} > /usr/bin/${n}
	chmod +x /usr/bin/${n}
done
echo "export OPENSHIFT_DIR=#{ORIGIN_DIR}/openshift.local.config/master" > /etc/profile.d/openshift.sh

# Check whether OpenShift is running, if so skip any further provisioning
state=$(docker inspect -f "{{.State.Running}}" ose 2>/dev/null)
if [ "${state}" == "true" ]; then
	echo "[INFO] Openshift already running"
	exit 0;
fi

# In a re-provision scenario we want to make sure the old container is removed
rm_ose_container

master_config=${OPENSHIFT_DIR}/master-config.yaml
node_config=${ORIGIN_DIR}/openshift.local.config/node-localhost.localdomain/node-config.yaml
if [ ! -f $master_config ]; then
  # Prepare directories for bind-mounting
  dirs=(openshift.local.volumes openshift.local.config openshift.local.etcd)
  for d in ${dirs[@]}; do
    mkdir -p ${ORIGIN_DIR}/${d} && chcon -Rt svirt_sandbox_file_t ${ORIGIN_DIR}/${d}
  done

  # First start OpenShift to just write the config files
  echo "[INFO] Preparing OpenShift config"

  start_ose --write-config=${ORIGIN_DIR}/openshift.local.config > /dev/null 2>&1
  wait_for_config_files ${master_config} ${node_config}

  # Now we need to make some adjustments to the config
  echo "[INFO] Configuring OpenShift via ${master_config}"

  sed -i.orig -e "s/\(.*subdomain:\).*/\1 $2/" ${master_config} \
    -e "s/\(.*masterPublicURL:\).*/\1 https:\/\/$1:8443/g" \
    -e "s/\(.*publicURL:\).*/\1 https:\/\/$1:8443\/console\//g" \
    -e "s/\(.*assetPublicURL:\).*/\1 https:\/\/$1:8443\/console\//g"

  # Remove the container
  rm_ose_container
fi

# Now we start the server pointing to the prepared config files
echo "[INFO] Starting OpenShift server"
start_ose --master-config="${master_config}" --node-config="${node_config}" > /dev/null 2>&1
wait_for_openshift

# Make sure kubeconfig is writable
chmod go+r ${KUBECONFIG}

# Create and expose Docker registry
# https://docs.openshift.com/enterprise/3.0/install_config/install/docker_registry.html#exposing-the-registry
if [ ! -f ${ORIGIN_DIR}/configured.registry ]; then
  echo "[INFO] Configuring Docker Registry"

  oadm registry --create --credentials=${OPENSHIFT_DIR}/openshift-registry.kubeconfig || exit 1
  oadm policy add-scc-to-group anyuid system:authenticated || exit 1
  touch ${ORIGIN_DIR}/configured.registry
fi

# For router, we have to create service account first and then use it for router creation.
if [ ! -f ${ORIGIN_DIR}/configured.router ]; then
  echo "[INFO] Configuring HAProxy router"

  echo '{"kind":"ServiceAccount","apiVersion":"v1","metadata":{"name":"router"}}' \
    | oc create -f -
  oc get scc privileged -o json \
    | sed '/\"users\"/a \"system:serviceaccount:default:router\",'  \
    | oc replace scc privileged -f -
  oadm router --create \
    --expose-metrics=true \
    --stats-port=1936 \
    --credentials=${OPENSHIFT_DIR}/openshift-router.kubeconfig \
    --service-account=router
  touch ${ORIGIN_DIR}/configured.router

  registry_host_name="hub.$2"
  oc expose service docker-registry --hostname ${registry_host_name}
fi

# Installing templates into OpenShift
if [ ! -f ${ORIGIN_DIR}/configured.templates ]; then
  echo "[INFO] Installing OpenShift templates"

  # TODO - These list must be verified and completed for a official release
  # Currently templates are sources from three main repositories
  # - openshift/origin
  # - openshift/nodejs-ex
  # - jboss-openshift/application-templates
  ose_tag=ose-v1.1.0
  template_list=(
    # Image streams
    https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-rhel7.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/jboss-image-streams.json
    # DB templates
    https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mongodb-ephemeral-template.json
    https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mongodb-persistent-template.json
    https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mysql-ephemeral-template.json
    https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/mysql-persistent-template.json
    https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/postgresql-ephemeral-template.json
    https://raw.githubusercontent.com/openshift/origin/master/examples/db-templates/postgresql-persistent-template.json
    # Jenkins
    https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/jenkins-ephemeral-template.json
    https://raw.githubusercontent.com/openshift/origin/master/examples/jenkins/jenkins-persistent-template.json
    # Node.js
    https://raw.githubusercontent.com/openshift/nodejs-ex/master/openshift/templates/nodejs-mongodb.json
    https://raw.githubusercontent.com/openshift/nodejs-ex/master/openshift/templates/nodejs.json
    # EAP
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-amq-persistent-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-amq-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-basic-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-https-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-mongodb-persistent-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-mongodb-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-mysql-persistent-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-mysql-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-postgresql-persistent-s2i.json
    https://raw.githubusercontent.com/jboss-openshift/application-templates/${ose_tag}/eap/eap64-postgresql-s2i.json
  )

  for template in ${template_list[@]}; do
    echo "[INFO] Importing template ${template}"
    oc create -f $template -n openshift >/dev/null
  done
  touch ${ORIGIN_DIR}/configured.templates
fi

# Configuring a test-admin user which can view the detault namespace
if [ ! -f ${ORIGIN_DIR}/configured.user ]; then
  echo "[INFO] Creating 'test-admin' user and 'test' project ..."
  oadm policy add-role-to-user view test-admin --config=${OPENSHIFT_DIR}/admin.kubeconfig
  sudo touch ${ORIGIN_DIR}/configured.user
fi
