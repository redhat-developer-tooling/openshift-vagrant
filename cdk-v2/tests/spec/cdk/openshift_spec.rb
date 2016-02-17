require 'spec_helper'
require 'net/http'
require 'uri'

# Tests verifying the correct installation of OpenShift
describe port(8443) do
  let(:disable_sudo) { false }
  it { should be_listening }
end

describe command('curl -k https://10.1.2.2:8443/console/') do
  its(:stdout) { should contain /OpenShift Web Console/ }
end

describe command('oc --insecure-skip-tls-verify login 10.1.2.2:8443 -u foo -p bar') do
  its(:stdout) { should contain /Login successful./ }
end

# Make sure we have at least some basic templates we are interested in
describe command('oc --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig get templates -n openshift') do
  its(:stdout) { should contain /eap64-basic-s2i/ }
  its(:stdout) { should contain /nodejs-example/ }
end

# Router is exposed
describe command('oc --config=/var/lib/origin/openshift.local.config/master/admin.kubeconfig  describe route/docker-registry') do
  its(:stdout) { should contain /hub.cdk.10.1.2.2.xip.io/ }
end

describe "Pushing arbitrary docker image" do
  it "should work" do
  	# Using Ghost as image to test. Pulled from Docker Hub
  	exit = command('docker pull ghost').exit_status
  	exit.should be 0

    # We need a project to "host" our image
  	exit = command('oc --insecure-skip-tls-verify login 10.1.2.2:8443 -u foo -p bar').exit_status
  	exit.should be 0
  	exit = command('oc new-project myproject').exit_status
  	exit.should be 0
  	token = command('oc whoami -t').stdout

    # 1 - Tag the image against the exposed OpenShift registry using the created project name as target
    # 2 - Log into the Docker registry
    # 3 - Push the image
  	exit = command('docker tag ghost hub.cdk.10.1.2.2.xip.io/myproject/ghost').exit_status
  	exit.should be 0
  	command("docker login -u foo -p #{token} -e foo@bar.com hub.cdk.10.1.2.2.xip.io")
  	exit = command('docker push hub.cdk.10.1.2.2.xip.io/myproject/ghost').exit_status
  	exit.should be 0

  	# 1 - Create the app from the image stream created by pusing the image
  	# 2 - Expose a route to the app
    exit = command('oc new-app --image-stream=ghost --name=ghost').exit_status
  	exit.should be 0
  	exit = command('oc expose service ghost --hostname=ghost.10.1.2.2.xip.io').exit_status
  	exit.should be 0
  	# TODO - instead of sleep we should use oc to monitor the state of the pod until running
  	sleep 30

    # Verify Ghost is up and running
    uri = URI.parse("http://ghost.10.1.2.2.xip.io")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    response.code.should match /200/

    # Cleanup
    # TODO - the teardown needs to go into a recue block or similar to make sure it gets
    # executed. Need to check how to do this with serverspec
    exit = command('docker rmi hub.cdk.10.1.2.2.xip.io/myproject/ghost').exit_status
  	exit.should be 0
    exit = command('oc delete all --all').exit_status
  	exit.should be 0
  	exit = command('oc delete project myproject').exit_status
  	exit.should be 0

    # Bye Bye
    command("oc logout").exit_status
    exit.should be 0
  end
end
