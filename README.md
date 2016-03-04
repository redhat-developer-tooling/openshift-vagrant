# All-in-One OpenShift Enterprise Vagrant VM

<!-- MarkdownTOC -->

- [What is it?](#what-is-it)
- [Prerequisites](#prerequisites)
- [How to run it](#how-to-run-it)
- [How to access the VM's Docker daemon](#how-to-access-the-vms-docker-daemon)
- [How to access the OpenShift registry](#how-to-access-the-openshift-registry)
- [OpenShift Logins](#openshift-logins)
  - [Regular users](#regular-users)
  - [admin](#admin)
  - [Cluster admin](#cluster-admin)
- [Known issues](#known-issues)
- [Misc](#misc)
  - [How to run _any_ image on OpenShift](#how-to-run-_any_-image-on-openshift)
  - [How to sync an existing OpenShift project](#how-to-sync-an-existing-openshift-project)
  - [How to get HAProxy statistics](#how-to-get-haproxy-statistics)
  - [How to test webhooks locally](#how-to-test-webhooks-locally)
  - [How to debug EAP image](#how-to-debug-eap-image)
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
* [vagrant-registration plugin](https://github.com/projectatomic/adb-vagrant-registration) _(>=1.2.1)_ installed
 * Run `vagrant plugin install vagrant-registration` to install plugin
* [vagrant-service-manager plugin](https://github.com/projectatomic/vagrant-service-manager) _(>=0.0.2)_ installed
 * Run `vagrant plugin install vagrant-service-manager` to install plugin
* Optionally, the [OpenShift Client tools](https://github.com/openshift/origin/releases/) for your OS to run the `oc` commands from the terminal.
* On Windows:
 * Ensure [Cygwin](https://www.cygwin.com/) is installed with rsync AND openssh. The default installation does not include these packages.

<a name="how-to-run-it"></a>
## How to run it

    $ cd cdk-v2
    $ export SUB_USERNAME=<your-subscription-username>
    $ export SUB_PASSWORD=<your-subscription-password>
    $ vagrant up

This will start and provision the VM, as well as start an all-in-One OpenShift
Enterprise instance. There are currently no scripts to start/stop OpenShift.
To restart OpenShift after an `vagrant halt`, run `vagrant up && vagrant provision`.
Provisioning steps which have already occurred will be skipped.

<a name="how-to-access-the-vms-docker-daemon"></a>
## How to access the VM's Docker daemon

Run `vagrant adbinfo`:

```
$ eval "$(vagrant adbinfo)"
```

Due to an [issue](https://github.com/projectatomic/vagrant-adbinfo/issues/55) with adbinfo, the first execution of `vagrant adbinfo` will currently kill your OpenShift
container. You need to run `vagrant provision` to restart the VM. This only occurs
on the first call to _adbinfo_.

<a name="how-to-access-the-openshift-registry"></a>
## How to access the OpenShift registry

The OpenShift registry is per default exposed as _hub.openshift.10.1.2.2.xip.io_. You can
push to this registry directly after logging in. Assuming one logs in as user 'foo':

    $ oc login 10.1.2.2:8443
    $ docker login -u foo -p `oc whoami -t` -e foo@bar.com hub.openshift.10.1.2.2.xip.io

<a name="openshift-logins"></a>
## OpenShift Logins

Once up an running the OpenShift console is accessible under https://10.1.2.2:8443/console/.

<a name="regular-users"></a>
### Regular users

The OpenShift instance setup with simple authentication. There is a _openshift-dev_
user with password _devel_ which can be used for creating projects and applications.

<a name="admin"></a>
### admin

There is also an _admin_ user who is member of the _cluster-admin_ group which
has permissions to do everything on any project.

<a name="cluster-admin"></a>
### Cluster admin

To make any administrative changes to the system, you can also login to the VM (`vagrant ssh`) and use the command line tools with the _--config_
option referencing the _system:admin_ configuration.

    $ vagrant ssh
    $ oadm --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig <whatever oadm command>
    $ oc --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig <whatever oc command>

Alternatively you can set the _KUBECONFIG_ environment variable and skip the _--config_ option.

    $ export KUBECONFIG=/var/lib/origin/openshift.local.config/master/admin.kubeconfig

However, be careful that when you in this case login as a different user, OpenShift
will attempt to overwrite _admin.kubeconfig_. Probably better to just define an
alias.

<a name="known-issues"></a>
## Known issues

* Causes of failure on Windows
 * Ensure `VAGRANT_DETECTED_OS=cygwin` is set

<a name="misc"></a>
## Misc

<a name="how-to-run-_any_-image-on-openshift"></a>
### How to run _any_ image on OpenShift

Assuming a user _foo_, you can do the following to run for example
the Node.js based blogging framework [Ghost](https://ghost.org/).

    $ oc login 10.1.2.2:8443
    Authentication required for https://10.1.2.2:8443 (openshift)
    Username: foo
    Password:
    Login successful.

    $ oc new-project my-ghost
    Now using project "my-ghost" on server "https://10.1.2.2:8443".

    $ docker pull ghost
    $ docker tag ghost hub.openshift.10.1.2.2.xip.io/my-ghost/ghost
    $ docker login -u foo -p `oc whoami -t` -e foo@bar.com hub.openshift.10.1.2.2.xip.io
    $ docker push hub.openshift.10.1.2.2.xip.io/my-ghost/ghost
    $ oc new-app --image-stream=ghost --name=ghost
    $ oc expose service ghost --hostname=my-ghost-blog.10.1.2.2.xip.io

Then visit http://my-ghost-blog.10.1.2.2.xip.io/ with your browser.



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

<a name="how-to-get-haproxy-statistics"></a>
### How to get HAProxy statistics

The OpenShift HAProxy is configured to expose some statistics about the routes.
This can sometimes be helpful when debugging problem or just to monitor traffic.
To access the statistics use [http://10.1.2.2:1936/](http://10.1.2.2:1936).

The username is '_admin_' and the password gets generated during the creation
of the router pod. You can run the following to find the password:

    $ eval "$(vagrant adbinfo)"
    $ docker ps # You want the container id of the ose-haproxy-router container
    $ docker exec <container-id-of-router> less /var/lib/haproxy/conf/haproxy.config | grep "stats auth"

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
