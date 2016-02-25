# Serverspec test suite for Vagrant OpenShift setup

<!-- MarkdownTOC -->

- [Getting started](#getting-started)
- [Running tests](#running-tests)
- [Tips](#tips)

<!-- /MarkdownTOC -->

This directory containts [Serverspec](http://serverspec.org/) tests to verify
the Vagrant OpenShift setup works and to document the expected behavior

<a name="getting-started"></a>
## Getting started

* Install a Ruby (2.2 is verified to work)
* Install Bundler - `gem install bundler --version 1.7.15`
* Install test harness dependencies - `bundle install`

<a name="running-tests"></a>
## Running tests

* `bundle exec rake -T` - view available rake tasks
* `bundle exec rake` - run all tests
* `bundle exec rake spec:cdk-all` - explicitly run all tests
* `bundle exec rake spec:cdk-smoke` - run smoke tests only
* `rake spec:cdk-smoke[10.10.10.2]` (or whatever the IP us you selected
  in the _Vagrantfile_) - run tests against a different IP

<a name="tips"></a>
## Tips

* You can run any `vagrant` command directly from the _test_ directory.
  Vagrant climbs up the directory tree looking for the first Vagrantfile it can find.
  See also - [Vagrantfile docs](https://www.vagrantup.com/docs/vagrantfile/).
