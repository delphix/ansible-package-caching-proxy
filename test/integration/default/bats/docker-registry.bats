#!/usr/bin/env bats
#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

#
# Test the Docker Registry server.
#

setup() {
    apt-get install -y curl
}

@test "The vhost for the docker registry should be available" {
    run curl --fail -sSq -H 'Host: registry' http://localhost
    [ "$status" -eq 0 ]
    [[ "$output" =~ "docker-registry server" ]]
}

@test "The docker registry's /_ping url should return valid JSON" {
    run bash -c "curl --fail -sSq -H 'Host: registry' http://localhost/_ping | python -m json.tool"
    [ "$status" -eq 0 ]
}

@test "The docker registry's /v1/_ping url should return valid JSON" {
    run bash -c "curl --fail -sSq -H 'Host: registry' http://localhost/v1/_ping | python -m json.tool"
    [ "$status" -eq 0 ]
}
