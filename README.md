# All-in-One OpenShift Enterprise Vagrant VM

## What is it

This repository contains a _Vagrantfile_ to start a Vagrant virtual machine
based on CDK 1.0.1, running a containerized version of OpenShift Enterprise.

## Prerequisites

The following prerequisites need to be met prior to creating and provisioning the
virtual machine:

* [VirtualBox](https://www.virtualbox.org/) installed
* [Vagrant](https://www.vagrantup.com/) installed
* [vagrant-registration plugin](https://github.com/projectatomic/adb-vagrant-registration) installed
 * Run `vagrant plugin install vagrant-registration` to install plugin
 * You can run `vagrant plugin list` after installation to verify the installation.
   Current version is 0.0.19
* RHEL employee subscription credentials available
* Active VPN connection during the creation and provisioning of the vm

## How do I run it

    $ cd cdk-v1
    $ export SUB_USERNAME=<your-subscription-username>
    $ export SUB_PASSWORD=<your-subscription-password>
    $ vagrant up

This will start and provision the vm as well as start an all-in-One OpenShift
Enterprise instance. There are currently no scripts to start/stop OpenShift.
To restart OpenShift after an `vagrant halt`, run `vagrant up && vagrant provision`.
Provisioning steps which have already occurred will be skipped and in the end a new
OpenShift instance is created. All state is lost in this case. To keep the state of
the running vm use `vagrant suspend` and `vagrant resume`.

### Known issues

* There is a known [issue](https://github.com/openshift/origin/issues/5355) which
  will send the OpenShift instance into overdrive, consuming pretty much all available
  CPU cycles. When it happens, all you can do for now is `vagrant destroy` followed by
  `vagrant up`.
* There are problems when using the Vagrant vbguest plugin in conjunction with the
  vagrant-registration plugin. The vbguest plugin will try running a yum update
  command prior the registration has taken place. To avoid this, uninstall the
  vbguest plugin or add the following to the _Vagrantfile_: `config.vbguest.auto_update = false`.

## How to use OpenShift instance

Once up an running the OpenShift console is accessible under https://10.1.2.2:8443/console/.

### Logins

#### Regular users

The OpenShift instance setup with no authentication, so you can choose any username
you like. If the username does not exist a user is create. The password can be
arbitrary (on each login).

#### _test-admin_

There is one user - _test-admin_ which is pre-configured. This user has _view_
permissions for the _default_ namespace. This can be handy, since in this namespace
the docker-registry and the router are running.

This user has no permissions to change anything in the default namespace!

#### Cluster admin

To make any administrative changes to the system, one has to cluster admin and
run the appropriate _oc_/_oadm_ commands.
To do so log onto the vagrant vm and use the command line tools with the _--config_
option referencing the system configuration.

    $ vagrant ssh
    $ oadm --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig <whatever oadm command>
    $ oc --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig <whatever oc command>

Alternatively you can set the _KUBECONFIG_ environment variable and skip the _--config_ option.

    $ export KUBECONFIG=/var/lib/origin/openshift.local.config/master/admin.kubeconfig

However, be careful that when you in this case login as a different user, OpenShift
will attempt to overwrite _admin.kubeconfig_. Probably better to just define an aliase.


## Tips and Tricks

### How to debug an EAP container

This is based using the _jboss-eap-6/eap-openshift:6.4_ image from
_registry.access.redhat.com_. This image is for example used by the _eap6-basic-sti_
template.

The startup script _standalone.sh_ for the EAP instance within this image checks the
variable _DEBUG_ to check whether to enable remote debugging on port 8787.

```
# Get the name of the deployment config.
$ oc get dc
NAME      TRIGGERS      LATEST VERSION
eap-app   ImageChange   1

# Check the current environment variables (optional)
$ oc env dc/eap-app --list
OPENSHIFT_DNS_PING_SERVICE_NAME=eap-app-ping
OPENSHIFT_DNS_PING_SERVICE_PORT=8888
HORNETQ_CLUSTER_PASSWORD=mVxpNmqt
HORNETQ_QUEUES=
HORNETQ_TOPICS=

# Set the DEBUG variable
$ oc env dc/eap-app DEBUG=true

# Double check the variable is set
$oc env dc/eap-app --list
OPENSHIFT_DNS_PING_SERVICE_NAME=eap-app-ping
OPENSHIFT_DNS_PING_SERVICE_PORT=8888
HORNETQ_CLUSTER_PASSWORD=mVxpNmqt
HORNETQ_QUEUES=
HORNETQ_TOPICS=
DEBUG=true

# Redeploy the latest image
$ oc deploy eap-app --latest -n eap

# Get the name of the running pod using the deployment config name as selector
$ oc get pods -l deploymentConfig=eap-app
NAME              READY     STATUS      RESTARTS   AGE
eap-app-3-rw4ko   1/1       Running     0          1h

# Port forward the debug port
$ oc port-forward eap-app-3-rw4ko 8787:8787
```

Once the `oc port-forward` command is executed, you can attach a remote
debugger to port 8787 on localhost.

### Ever wanted to explore the OpenShift REST API

Try this:
* Open [this](http://openshift3swagger-claytondev.rhcloud.com) link in a browser
* Paste the URL of the OpenShift instance (https://10.1.2.2:8443/swaggerapi/oapi/v1) into the input field




