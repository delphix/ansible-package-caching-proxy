#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

VAGRANTFILE_API_VERSION = "2"


# The "docker-py" Python module is needed to run Ansible within the container
$script = <<SCRIPT
if [ ! -f /home/vagrant/.provisioned ]; then
    apt-get -y install python-pip
    pip install docker-py
    touch /home/vagrant/.provisioned
fi
SCRIPT


Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.box = "metcalfc/trusty-docker"

    config.vm.network "forwarded_port", guest: 80, host: 8080
    config.vm.network "forwarded_port", guest: 1080, host: 1080
    config.vm.network "forwarded_port", guest: 3141, host: 3141
    config.vm.network "forwarded_port", guest: 3142, host: 3142
    config.vm.network "forwarded_port", guest: 5000, host: 5000

    config.vm.provision "shell", inline: $script

    config.vm.provision "ansible" do |ansible|
        ansible.playbook = "test.yml"
        ansible.sudo = true  # We ssh in as "vagrant" user so we need to sudo.
        ansible.verbose = 'v'  # More "v"s means more verbosity!
    end
end
