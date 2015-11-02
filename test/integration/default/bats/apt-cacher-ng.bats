#!/usr/bin/env bats
#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

#
# Test the apt-cacher-ng app.
#

PACKAGE_SERVER=ftp.debian.org/debian


setup() {
    apt-get install -y curl
}

@test "Accessing the apt-cacher-ng vhost should load the configuration page for Apt-Cacher-NG" {
    run curl -sSq -H 'Host: apt-cache' http://localhost
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Apt-Cacher-NG" ]]
}

@test "Hitting the apt-cacher proxy on the proxy port should succeed" {
    run curl -sS http://localhost:3142/$PACKAGE_SERVER
    [ "$status" -eq 0 ]
}

@test "The previous command that hit ftp.debian.org should have placed some files in the cache" {
    run ls -l /opt/apt-cache/$PACKAGE_SERVER
    [ "$status" -eq 0 ]
}
