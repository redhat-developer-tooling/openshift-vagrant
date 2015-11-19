#!/usr/bin/env bash

# Prepare, configure and start OpenShift
#
# $1 : Public Red Hat Docker registory host
# $2 : Public IP Address

set -o pipefail
set -o nounset
#set -o xtrace

export OSE_IMAGE_NAME=openshift3/ose
export ORIGIN_DIR="/var/lib/origin"
export OPENSHIFT_DIR=${ORIGIN_DIR}/openshift.local.config/master
export KUBECONFIG=${OPENSHIFT_DIR}/admin.kubeconfig

# Check whether a OpenShift image exists and if not pull and tag it
docker inspect openshift3/ose &>/dev/null
if [ $? -eq 0 ]
then
  echo "[INFO] Skipping pull of OpenShift image "
else
  echo "[INFO] Pulling ${OSE_IMAGE_NAME} Docker image ..."
  docker pull $1/${OSE_IMAGE_NAME}
  docker tag $1/${OSE_IMAGE_NAME} openshift3/ose
fi

binaries=(oc oadm)
for n in ${binaries[@]}; do
  [ -f /usr/bin/${n} ] && continue
  echo "[INFO] Copying the OpenShift '${n}' binary to host /usr/bin/${n}"
  docker run --rm --entrypoint=/bin/cat openshift3/ose /usr/bin/${n} > /usr/bin/${n}
  chmod +x /usr/bin/${n}
done
echo "export OPENSHIFT_DIR=#{ORIGIN_DIR}/openshift.local.config/master" > /etc/profile.d/openshift.sh

# Start OpenShift
state=$(docker inspect -f "{{.State.Running}}" ose 2>/dev/null)
if [ "${state}" == "true" ]
then
  echo "[INFO] Skipping OpenShift configuration. Already running"
  exit 0;
fi

if docker inspect ose &>/dev/null
then
  echo "[INFO] Removing previously started OpenShift container ..."
  docker rm -f -v ose > /dev/null 2>&1
fi

echo "[INFO] Starting OpenShift server ..."

# Prepare directories for bind-mounting
dirs=(openshift.local.volumes openshift.local.config openshift.local.etcd)
for d in ${dirs[@]}; do
  mkdir -p ${ORIGIN_DIR}/${d} && chcon -Rt svirt_sandbox_file_t ${ORIGIN_DIR}/${d}
done

docker run -d --name "ose" --privileged --net=host --pid=host \
     -v /:/rootfs:ro \
     -v /var/run:/var/run:rw \
     -v /sys:/sys:ro \
     -v /var/lib/docker:/var/lib/docker:rw \
     -v ${ORIGIN_DIR}/openshift.local.volumes:${ORIGIN_DIR}/openshift.local.volumes:z \
     -v ${ORIGIN_DIR}/openshift.local.config:${ORIGIN_DIR}/openshift.local.config:z \
     -v ${ORIGIN_DIR}/openshift.local.etcd:${ORIGIN_DIR}/openshift.local.etcd:z \
     openshift3/ose start \
      --master="https://${2}:8443" \
      --etcd-dir="${ORIGIN_DIR}/openshift.local.etcd" \
      --cors-allowed-origins=.* > /dev/null 2>&1

sleep 15 # Give OpenShift 15 seconds to start
chmod go+r ${KUBECONFIG}

state=$(docker inspect -f "{{.State.Running}}" ose)
if [[ "${state}" != "true" ]]; then
  >&2 echo "[ERROR] OpenShift failed to start:"
  docker logs ose
  exit 1
fi

# Create Docker Registry
if [ ! -f ${ORIGIN_DIR}/configured.registry ]; then
  echo "[INFO] Configuring Docker Registry ..."
  oadm registry --create --credentials=${OPENSHIFT_DIR}/openshift-registry.kubeconfig
  touch ${ORIGIN_DIR}/configured.registry
fi

# For router, we have to create service account first and then use it for router creation.
if [ ! -f ${ORIGIN_DIR}/configured.router ]; then
  echo "[INFO] Configuring HAProxy router ..."
  echo '{"kind":"ServiceAccount","apiVersion":"v1","metadata":{"name":"router"}}' \
    | oc create -f -
  oc get scc privileged -o json \
    | sed '/\"users\"/a \"system:serviceaccount:default:router\",'  \
    | oc replace scc privileged -f -
  oadm router --create --credentials=${OPENSHIFT_DIR}/openshift-router.kubeconfig \
    --service-account=router
  touch ${ORIGIN_DIR}/configured.router
fi

# Downloading application templates
EXAMPLES_BASE=/opt/openshift/templates
if [ ! -d "${EXAMPLES_BASE}"  ]
then
  echo "[INFO] Downloading OpenShift and xPaaS templates ..."
  temp_dir=$(mktemp -d)
  pushd ${temp_dir} >/dev/null
  mkdir -p ${EXAMPLES_BASE}/{db-templates,image-streams,quickstart-templates,xpaas-streams,xpaas-templates}
  curl -sL https://github.com/openshift/origin/archive/master.zip -o origin-master.zip
  curl -sL https://github.com/openshift/nodejs-ex/archive/master.zip -o nodejs-ex-master.zip
  curl -sL https://github.com/jboss-openshift/application-templates/archive/ose-v1.0.2.zip -o application-templates-ose-v1.0.2.zip
  unzip -q nodejs-ex-master.zip
  unzip -q origin-master.zip
  unzip -q application-templates-ose-v1.0.2.zip
  cp origin-master/examples/db-templates/* ${EXAMPLES_BASE}/db-templates/
  cp origin-master/examples/jenkins/jenkins-*template.json ${EXAMPLES_BASE}/quickstart-templates/
  cp origin-master/examples/image-streams/* ${EXAMPLES_BASE}/image-streams/
  cp nodejs-ex-master/openshift/templates/* ${EXAMPLES_BASE}/quickstart-templates/
  cp -R application-templates-ose-v1.0.2/* ${EXAMPLES_BASE}/xpaas-templates/
  mv application-templates-ose-v1.0.2/jboss-image-streams.json ${EXAMPLES_BASE}/xpaas-streams/
  rm -f /opt/openshift/templates/xpaas-streams/jboss-image-streams.json
  rm -f /opt/openshift/templates/image-streams/image-streams-centos7.json
  rm -f /opt/openshift/templates/xpaas-templates/eap/eap6-https-sti.json
  rm -f /opt/openshift/templates/xpaas-templates/webserver/jws-tomcat8-basic-sti.json
  rm -f /opt/openshift/templates/xpaas-templates/webserver/jws-tomcat7-https-sti.json
  popd >/dev/null
  rm -rf ${temp_dir}
else
  echo "[INFO] Skipping download of OpenShift templates. ${EXAMPLES_BASE} already exists"
fi

if [ ! -f ${ORIGIN_DIR}/configured.templates ]
then
  echo "[INFO] Installing OpenShift templates ..."
  for name in $(find /opt/openshift/templates -name '*.json')
  do
    oc create -f $name -n openshift >/dev/null
  done
  touch ${ORIGIN_DIR}/configured.templates
fi

if [ ! -f ${ORIGIN_DIR}/configured.user ]
then
  echo "[INFO] Creating 'test-admin' user and 'test' project ..."
  oadm policy add-role-to-user view test-admin --config=${OPENSHIFT_DIR}/admin.kubeconfig
  oc login https://${2}:8443 -u test-admin -p test \
    --certificate-authority=${OPENSHIFT_DIR}/ca.crt &>/dev/null
  oc new-project test --display-name="OpenShift 3 Sample" \
    --description="This is an example project to demonstrate OpenShift v3" &>/dev/null
  sudo touch ${ORIGIN_DIR}/configured.user
fi
