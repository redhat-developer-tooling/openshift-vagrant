# All-in-One OpenShift Enterprise Vagrant VM

<!-- MarkdownTOC -->

- [What is it?](#what-is-it)
- [Prerequisites](#prerequisites)
- [How do I run it?](#how-do-i-run-it)
  - [Known issues](#known-issues)
- [Logins](#logins)
  - [Regular users](#regular-users)
  - [_test-admin_](#_test-admin_)
  - [Cluster admin](#cluster-admin)
- [Misc](#misc)
  - [Exposing OpenShift routes to the host](#exposing-openshift-routes-to-the-host)
  - [How to debug EAP image](#how-to-debug-eap-image)
  - [Run images which use USER directive in Dockerfile](#run-images-which-use-user-directive-in-dockerfile)
  - [Find cause of container startup failure](#find-cause-of-container-startup-failure)
  - [Explore the OpenShift REST API](#explore-the-openshift-rest-api)

<!-- /MarkdownTOC -->

<a name="what-is-it"></a>
## What is it?

This repository contains a _Vagrantfile_ to start a Vagrant virtual machine
based on CDK 1.0.1, running a containerized version of OpenShift Enterprise.

<a name="prerequisites"></a>
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

<a name="how-do-i-run-it"></a>
## How do I run it?

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

<a name="known-issues"></a>
### Known issues

* ~~There is a known [issue](https://github.com/openshift/origin/issues/5355) which
  will send the OpenShift instance into overdrive, consuming pretty much all available
  CPU cycles. When it happens, all you can do for now is `vagrant destroy` followed by
  `vagrant up`.~~
* There are problems when using the Vagrant vbguest plugin in conjunction with the
  vagrant-registration plugin. The vbguest plugin will try running a yum update
  command prior the registration has taken place. To avoid this, uninstall the
  vbguest plugin or add the following to the _Vagrantfile_: `config.vbguest.auto_update = false`.

<a name="logins"></a>
## Logins

Once up an running the OpenShift console is accessible under https://10.1.2.2:8443/console/.

<a name="regular-users"></a>
### Regular users

The OpenShift instance setup with no authentication, so you can choose any username
you like. If the username does not exist a user is create. The password can be
arbitrary (on each login).

<a name="_test-admin_"></a>
### _test-admin_

There is one user - _test-admin_ which is pre-configured. This user has _view_
permissions for the _default_ namespace. This can be handy, since in this namespace
the docker-registry and the router are running.

This user has no permissions to change anything in the default namespace!

<a name="cluster-admin"></a>
### Cluster admin

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
will attempt to overwrite _admin.kubeconfig_. Probably better to just define an alias.

<a name="misc"></a>
## Misc

<a name="exposing-openshift-routes-to-the-host"></a>
### Exposing OpenShift routes to the host

Currently there is no solution for this on Windows (work on a automatic soltution
is in progress), except manually editing the hosts file and adding entries of the
form:

```
10.1.2.2 <routename>-<project>.router.default.svc.cluster.local
```

This will also work for OS X and Linux, however, in these cases you can also
use the [Landrush](https://github.com/phinze/landrush) Vagrant plugin. Adding
the following to your _Vagrantfile_ should get you sorted:

```
config.landrush.enabled = true
config.landrush.host 'router.default.svc.cluster.local', "#{PUBLIC_ADDRESS}"
config.landrush.guest_redirect_dns = false
```

This will work out of the boc on OS X. On Linux you alo need _dnsmasq_. Check
the Landrush documentation.

<a name="how-to-debug-eap-image"></a>
### How to debug EAP image

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

<a name="run-images-which-use-user-directive-in-dockerfile"></a>
### Run images which use USER directive in Dockerfile

Out of security reasons, images run on OpenShift are not honoring the _USER_
directive. This can lead to very misleading errors. OpenShift "enabled" images
currently avoid the _USER_ directive, but standard Docker Hub images tend to change
the user.
See also [this](https://github.com/openshift/origin/issues/5693) OpenShift issue.
To run images with _USER_ directive, run the following as cluster admin:

```
$ oc --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig edit scc restricted
```
Change the _runAsUser.Type_ strategy to _RunAsAny_. More info [here](https://docs.openshift.org/latest/admin_guide/manage_scc.html#enable-images-to-run-with-user-in-the-dockerfile).

<a name="find-cause-of-container-startup-failure"></a>
### Find cause of container startup failure

In conjunction with trying to run arbitrary Docker images on OpenShift, it can be
hard to track down deployment errors. If the deployment of a pot fails, OpenShift
will try to reschedule a deployment and the original pod won't be available anymore.
In this case you can try accessing the logs of the failing container directly
via Docker commands against the Docker daemon running within the VM (the Docker
daemon of the VM is used by the OpenShift instance itself as well).


View the docker logs

```
$ vagrant ssh

# Find the container id of the failing container (looking for the latest created container)
$ docker ps -l -q
5b37abf17fb6

$ docker logs 5b37abf17fb6
```

<a name="explore-the-openshift-rest-api"></a>
### Explore the OpenShift REST API

Try this:
* Open [this](http://openshift3swagger-claytondev.rhcloud.com) link in a browser
* Paste the URL of the OpenShift instance (https://10.1.2.2:8443/swaggerapi/oapi/v1) into the input field




