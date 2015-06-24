# Contributing

## How To Contribute

  * [File an issue](https://github.com/delphix/ansible-package-caching-proxy/issues)
  * Send a [Pull Request](https://github.com/mitchellh/vagrant/pulls)

## Testing

Test Kitchen is a tool for automated testing of configuration management code
executed by tools like Ansible.

See the following links for more info:

  * https://github.com/test-kitchen/test-kitchen
  * https://github.com/neillturner/kitchen-ansible
  * http://serverspec.org/resource_types.html
  * http://www.slideshare.net/MartinEtmajer/testing-ansible-roles-with-test-kitchen-serverspec-and-rspec-48185017

### Pre-Reqs

#### Install VirtualBox and Vagrant:

  * https://www.virtualbox.org
  * https://www.vagrantup.com

#### Install Test Kitchen

  * Install Test Kitchen, and its Ansible & Vagrant plugins via `gem`:

        gem install test-kitchen
        gem install kitchen-ansible
        gem install kitchen-vagrant

### Running Test Kitchen

From the top-level directory of the repo which contains the `.kitchen.yml` file:

        kitchen test
