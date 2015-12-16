# All-in-One OpenShift Enterprise Vagrant VM

<!-- MarkdownTOC -->

- [What is it?](#what-is-it)
- [Prerequisites](#prerequisites)
- [How do I run it](#how-do-i-run-it)
  - [How to access the VM's Docker daemon](#how-to-access-the-vms-docker-daemon)
  - [Known issues](#known-issues)
- [OpenShift Logins](#openshift-logins)
  - [Regular users](#regular-users)
  - [_test-admin_](#_test-admin_)
  - [Cluster admin](#cluster-admin)
- [Misc](#misc)
  - [How to sync an existing OpenShift project](#how-to-sync-an-existing-openshift-project)
  - [How to test webhooks locally](#how-to-test-webhooks-locally)
  - [How to debug EAP image](#how-to-debug-eap-image)
  - [How to run images which use USER directive in Dockerfile](#how-to-run-images-which-use-user-directive-in-dockerfile)
  - [How to find cause of container startup failure](#how-to-find-cause-of-container-startup-failure)
  - [How to explore the OpenShift REST API](#how-to-explore-the-openshift-rest-api)

<!-- /MarkdownTOC -->

<a name="what-is-it"></a>
## What is it?

This repository contain a Vagrant setup to start a Vagrant virtual machine
running a containerized version of OpenShift Enterprise using CDK 2 (Beta3).

<a name="prerequisites"></a>
## Prerequisites

The following prerequisites need to be met prior to creating and provisioning the
virtual machine:

* __RHEL employee subscription credentials available__
* __Active VPN connection during the creation and provisioning of the VM__
* [VirtualBox](https://www.virtualbox.org/) installed
* [Vagrant](https://www.vagrantup.com/) installed
* [vagrant-registration plugin](https://github.com/projectatomic/adb-vagrant-registration) _(>=1.0.0)_ installed
 * Run `vagrant plugin install vagrant-registration` to install plugin
* [vagrant-adbinfo plugin](https://github.com/bexelbie/vagrant-adbinfo) _(>=0.0.9)_ installed
 * Run `vagrant plugin install vagrant-adbinfo` to install plugin
* On Windows:
 * Ensure [PuTTY](http://www.putty.org/) utilities, including pscp, are installed and on the _Path_. See also vagrant-adbinfo issue [#20](https://github.com/projectatomic/vagrant-adbinfo/issues/20)
 * Ensure [Cygwin](https://www.cygwin.com/) is installed with rsync AND openssh. The default installation does not include these packages.

<a name="how-do-i-run-it"></a>
## How do I run it

    $ cd cdk-v2
    $ export SUB_USERNAME=<your-subscription-username>
    $ export SUB_PASSWORD=<your-subscription-password>
    $ vagrant up

This will start and provision the VM, as well as start an all-in-One OpenShift
Enterprise instance. There are currently no scripts to start/stop OpenShift.
To restart OpenShift after an `vagrant halt`, run `vagrant up && vagrant provision`.
Provisioning steps which have already occurred will be skipped.

<a name="how-to-access-the-vms-docker-daemon"></a>
### How to access the VM's Docker daemon

Run `vagrant adbinfo`:

```
$ eval "$(vagrant adbinfo)"
$ unset DOCKER_TLS_VERIFY
```

Due to an [issue](projectatomic/adb-atomic-developer-bundle#127) with the generated
CDK certificates, this Vagrant setup disables TLS verification.
For this reason we are unsetting _DOCKER_TLS_VERIFY_ for now.

<a name="known-issues"></a>
### Known issues

* There are problems when using the Vagrant vbguest plugin in conjunction with the
  vagrant-registration plugin. The vbguest plugin will try running a yum update
  command prior the registration has taken place. To avoid this, uninstall the
  vbguest plugin or add the following to the _Vagrantfile_: `config.vbguest.
  auto_update = false`.
* Causes of failure on Windows
 * Ensure `VAGRANT_DETECTED_OS=cygwin` is set


<a name="openshift-logins"></a>
## OpenShift Logins

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

<a name="how-to-sync-an-existing-openshift-project"></a>
### How to sync an existing OpenShift project

First step is to export the configuration from the existing project:

```
$ oc export is,bc,dc,svc,route -o json > project-config.json
```

At this stage you probably want to edit the json and change the route.
You can do this also after the import by `oc edit route`.

Then on the second instance, create a new project, import the resources
and trigger a new build:

```
$ oc new-project foo
$ oc create -f project-config.json
$ oc new-build <build-config-name>
```

<a name="how-to-test-webhooks-locally"></a>
### How to test webhooks locally

Since the created VM is only visible on the host, GitHub webhooks won't work, since
GitHub cannot reach the VM. Obviously you can just trigger the build via _oc_:

```
$ oc start-build <build-config-name>
```

If you want to ensure that the actual webhooks work though, you can trigger them
via curl as well. First determine the URLs of the GitHub and generic URL:

```
$ oc describe <build-config-name>
```

To trigger the generic hook run:
```
$ curl -k -X POST <generic-hook-url>
```

To trigger the GitHub hook run:
```
$ curl -k \
-H "Content-Type: application/json" \
-H "X-Github-Event: push" \
-X POST -d '{"ref":"refs/heads/master"}' \
<github-hook-url>
```

The GitHub payload is quite extensive, but the only thing which matters from
an OpenShift perspective at the moment is that the _ref_ matches.

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

<a name="how-to-run-images-which-use-user-directive-in-dockerfile"></a>
### How to run images which use USER directive in Dockerfile

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

<a name="how-to-find-cause-of-container-startup-failure"></a>
### How to find cause of container startup failure

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

<a name="how-to-explore-the-openshift-rest-api"></a>
### How to explore the OpenShift REST API

Try this:
* Open [this](http://openshift3swagger-claytondev.rhcloud.com) link in a browser
* Paste the URL of the OpenShift instance "https://10.1.2.2:8443/swaggerapi/oapi/v1" into the input field




