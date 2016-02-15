require 'spec_helper'

###############################################################################
# Tests verifying everything Docker
###############################################################################
describe service('docker') do
  it { should be_enabled }
end

describe service('docker') do
  it { should be_running }
end

describe file('/etc/sysconfig/docker') do
  it { should contain 'registry.access.redhat.com' }
end

describe docker_container('openshift') do
  it { should be_running }
end

describe command('docker ps --filter "name=k8s_registry.*"') do
  its(:stdout) { should match /ose-docker-registry/ }
end

describe command('docker ps --filter "name=k8s_router.*"') do
  its(:stdout) { should match /ose-haproxy-router/ }
end
