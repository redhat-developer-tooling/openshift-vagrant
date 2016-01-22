require 'spec_helper'

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
