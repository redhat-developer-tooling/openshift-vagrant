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
    - [How to use Landrush](#how-to-use-landrush)
    - [How to use persistent volumes claims](#how-to-use-persistent-volumes-claims)
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
running a containerized version of OpenShift Enterprise using CDK 2.

<a name="prerequisites"></a>
## Prerequisites

The following prerequisites need to be met prior to creating and provisioning the
virtual machine:

* __[developers.redhat.com](http://developers.redhat.com) or Red Hat employee subscription credentials__
* __Active VPN connection during the creation and provisioning of the VM__
* [VirtualBox](https://www.virtualbox.org/) installed
* [Vagrant](https://www.vagrantup.com/) installed
* [vagrant-registration plugin](https://github.com/projectatomic/adb-vagrant-registration) _(>=1.2.1)_ installed
 * Run `vagrant plugin install vagrant-registration` to install plugin
* [vagrant-service-manager plugin](https://github.com/projectatomic/vagrant-service-manager) _(>=1.0.1)_ installed.
 * Run `vagrant plugin install vagrant-service-manager` to install plugin
* [vagrant-sshfs plugin](https://github.com/dustymabe/vagrant-sshfs) _(>=1.1.0)_ installed
 * Run `vagrant plugin install vagrant-sshfs` to install plugin
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
Enterprise instance.

<a name="how-to-access-the-vms-docker-daemon"></a>
## How to access the VM's Docker daemon

Run the following command in your shell to configure it to use Docker (you need
the Docker CLI binaries installed):

```
$ eval "$(vagrant service-manager env docker)"
```

<a name="how-to-access-the-openshift-registry"></a>
## How to access the OpenShift registry

The OpenShift registry is per default exposed as _hub.openshift.10.1.2.2.xip.io_. You can
push to this registry directly after logging in. Assuming one logs in as
the defaultuser 'openshift-dev':

    $ oc login 10.1.2.2:8443 -u openshift-dev -p devel
    $ docker login -u openshift-dev -p `oc whoami -t` -e foo@bar.com hub.openshift.rhel-cdk.10.1.2.2.xip.io

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
will attempt to overwrite _admin.kubeconfig_.

<a name="known-issues"></a>
## Known issues

* Causes of failure on Windows
 * Ensure `VAGRANT_DETECTED_OS=cygwin` is set

<a name="misc"></a>
## Misc

<a name="how-to-use-landrush"></a>
### How to use Landrush

NOTE: Not working on Windows for now unless you build Landrush from source!

Set the environment variable `OPENSHIFT_VAGRANT_USE_LANDRUSH`

    $ cd cdk-v2
    $ export SUB_USERNAME=<your-subscription-username>
    $ export SUB_PASSWORD=<your-subscription-password>
    $ export OPENSHIFT_VAGRANT_USE_LANDRUSH=true
    $ vagrant up

The generated routes will then use _openshift.cdk_ as TLD instead of _10.1.2.2.xip.io_.

<a name="how-to-use-persistent-volumes-claims"></a>
### How to use persistent volumes claims

The CDK provides a three persistent volumnes to experiment with. You can view them
as admin as so:

    $ oc login -u admin -p password
    $ oc get pv
    NAME      LABELS    CAPACITY   ACCESSMODES   STATUS      CLAIM     REASON    AGE
    pv01      <none>    1Gi        RWO,RWX       Available                       6h
    pv02      <none>    2Gi        RWO,RWX       Available                       6h
    pv03      <none>    3Gi        RWO,RWX       Available                       6h

To make a claim, you can do the following:

    # Using the openshift-dev user
    $ oc login -u openshift-dev -p devel

    # Using Nodejs as example app
    $ oc new-app https://github.com/openshift/nodejs-ex -l name=nodejs
    # Wait for build to complete ...
    $ oc expose service nodejs-ex -l name=nodejs

    # Make the persistent volume claim
    $ oc volume dc/nodejs-ex --add --claim-size 512M --mount-path  /opt/app-root/src/views --name views
    persistentvolumeclaims/pvc-evu2v
    deploymentconfigs/nodejs-ex

    # Check the persistent volume claim
    oc get pvc
    NAME        LABELS    STATUS    VOLUME    CAPACITY   ACCESSMODES   AGE
    pvc-evu2v   <none>    Bound     pv01      1Gi        RWO,RWX       1m

    # create some sample file
    $ echo '<html><body><h1>It works!</h1></body></html>' > /nfsvolumes/pv01/index.html

    # Brose to http://nodejs-ex-sample-project.rhel-cdk.10.1.2.2.xip.io/

    # Verfify content on file system
    $ vagrant ssh
    $ ls -l /nfsvolumes/pv01

    # All app of the same app share the same volume
    $ oc scale dc/nodejs-ex --replicas 5
    $ oc get pods
    NAME                READY     STATUS      RESTARTS   AGE
    nodejs-ex-1-build   0/1       Completed   0          41m
    nodejs-ex-6-2hs75   1/1       Running     0          15m
    nodejs-ex-6-f576b   1/1       Running     0          1m
    nodejs-ex-6-fboe9   1/1       Running     0          1m
    nodejs-ex-6-ldaq1   1/1       Running     0          1m
    nodejs-ex-6-norrq   1/1       Running     0          1m

    $ oc exec -it nodejs-ex-6-norrq sh
    $ cat views/index.html

<a name="how-to-run-_any_-image-on-openshift"></a>
### How to run _any_ image on OpenShift

Assuming user _openshift-dev_, you can do the following to run for example
the Node.js based blogging framework [Ghost](https://ghost.org/).

    $ oc login 10.1.2.2:8443 -u openshift-dev -p devel
    Login successful.

    $ oc new-project my-ghost
    Now using project "my-ghost" on server "https://10.1.2.2:8443".

    $ docker pull ghost
    $ docker tag ghost hub.openshift.rhel-cdk.10.1.2.2.xip.io/my-ghost/ghost
    $ docker login -u openshift-dev -p `oc whoami -t` -e foo@bar.com hub.openshift.rhel-cdk.10.1.2.2.xip.io
    $ docker push hub.openshift.rhel-cdk.10.1.2.2.xip.io/my-ghost/ghost
    $ oc new-app --image-stream=ghost --name=ghost
    $ oc expose service ghost --hostname=my-ghost-blog.rhel-cdk.10.1.2.2.xip.io

Then visit http://my-ghost-blog.rhel-cdk.10.1.2.2.xip.io/ with your browser.

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

    $ eval "$(vagrant service-manager env docker)"
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
