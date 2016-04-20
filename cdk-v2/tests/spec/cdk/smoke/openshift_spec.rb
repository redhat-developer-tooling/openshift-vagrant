require 'spec_helper'
require 'net/http'
require 'uri'

###############################################################################
# Tests verifying the correct installation of OpenShift
###############################################################################

describe service('openshift') do
  it { should be_enabled }
end

describe service('openshift') do
  it { should be_running }
end

describe port(8443) do
  let(:disable_sudo) { false }
  it { should be_listening }
end

describe command("curl -k https://#{ENV['TARGET_IP']}:8443/console/") do
  its(:stdout) { should contain /OpenShift Web Console/ }
end

describe command("oc --insecure-skip-tls-verify login #{ENV['TARGET_IP']}:8443 -u openshift-dev -p devel") do
  its(:stdout) { should contain /Login successful./ }
end

describe command("oc --insecure-skip-tls-verify login #{ENV['TARGET_IP']}:8443 -u admin -p admin") do
  its(:stdout) { should contain /Login successful./ }
end

describe "OpenShift registry route" do
  it "should be exposed" do
    registry_get = command('sudo oc --config=/var/lib/openshift/openshift.local.config/master/admin.kubeconfig get route/docker-registry').stdout
    registry_get.should contain /hub.openshift.rhel-cdk.#{Regexp.quote(ENV['TARGET_IP'])}.xip.io/
  end
end

describe "Login to OpenShift registry via exposed registry route hub.openshift.rhel-cdk.#{ENV['TARGET_IP']}.xip.io" do
  it "should succeed" do
    exit = command("oc --insecure-skip-tls-verify login #{ENV['TARGET_IP']}:8443 -u openshift-dev -p devel").exit_status
    exit.should be 0
    token = command('oc whoami -t').stdout
    exit = command("docker login -u openshift-dev -p '#{token}' -e foo@bar.com hub.openshift.rhel-cdk.#{ENV['TARGET_IP']}.xip.io").exit_status
    exit.should be 0
  end

  after do
    command('oc logout').exit_status.should be 0
    command('rm /home/vagrant/.docker/config.json').exit_status.should be 0
  end
end

describe "Admin user" do
  it "should be able to list OpenShift nodes" do
    command("oc --insecure-skip-tls-verify login #{ENV['TARGET_IP']}:8443 -u admin -p admin").exit_status.should be 0
    nodes = command('oc get nodes').stdout
    nodes.should contain /rhel-cdk/
  end

  after do
    command('oc logout').exit_status.should be 0
  end
end

describe "Basic application templates" do
  it "should exist" do
    command("oc --insecure-skip-tls-verify login #{ENV['TARGET_IP']}:8443 -u admin -p admin").exit_status.should be 0
    templates = command('oc --insecure-skip-tls-verify get templates -n openshift').stdout
    # TODO - complete list after requirements are set
    templates.should contain /eap64-basic-s2i/
    templates.should contain /eap64-mysql-persistent-s2i/
    templates.should contain /nodejs-example/
  end

  after do
    command('oc logout').exit_status.should be 0
  end
end

describe "OpenShift health URL" do
  it "should respond with response code 200" do
    uri = URI.parse("https://#{ENV['TARGET_IP']}:8443/healthz/ready")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    response.code.should match /200/
  end
end

describe file('/usr/bin/oc') do
  it { should be_file }
  it { should be_executable }
end

describe file('/usr/bin/oadm') do
  it { should be_symlink }
  it { should be_linked_to '/usr/bin/openshift' }
  it { should be_executable }
end

