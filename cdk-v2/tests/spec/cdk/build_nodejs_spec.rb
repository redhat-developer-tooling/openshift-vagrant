require 'spec_helper'

###############################################################################
# Tests verifying pushing an arbitrary image
###############################################################################

describe "Nodejs example app" do
  let(:disable_sudo) { false }
  it "should build" do
    # Login
    command("oc --insecure-skip-tls-verify login #{ENV['TARGET_IP']}:8443 -u openshift-dev -p devel").exit_status.should be 0

    # Create a new project
    command('oc new-project nodejs').exit_status.should be 0

    # Create the app
    command('oc new-app nodejs-example').exit_status.should be 0
    sleep 5

    i = 0
    while i < 60
        state = command('oc get pods --no-headers').stdout.split[2]
        case state
        when "Pending"
            puts 'Pulling builder image'
            sleep 10
        when "Running"
            puts 'Building app'
            sleep 10
        when "Completed"
            # TODO give time to get the pod up, needs improvement
            puts 'Build complete. Waiting for pod to start'
            sleep 10
            break
        else
            fail "Unexpected builder pod state: #{state}"
        end
        i = i+1
    end

    # Verify Nodejs app is up and running
    uri = URI.parse("http://nodejs-example-nodejs.rhel-cdk.#{ENV['TARGET_IP']}.xip.io")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    response.code.should match /200/
    response.body.should match /Welcome to your Node.js application on OpenShift/
  end

  after do
    command('oc delete all --all').exit_status.should be 0
    command('oc delete project nodejs').exit_status.should be 0
    command('oc logout').exit_status.should be 0
  end
end

