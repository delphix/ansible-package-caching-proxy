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
    run curl -sSq -H 'Host: registry' http://localhost
    [ "$status" -eq 0 ]
    [[ "$output" =~ "docker-registry server" ]]
}

@test "The docker registry's /_ping url should return valid JSON" {
    run bash -c "curl -sSq -H 'Host: registry' http://localhost/_ping | python -m json.tool"
    [ "$status" -eq 0 ]
}

@test "The docker registry's /v1/_ping url should return valid JSON" {
    run bash -c "curl -sSq -H 'Host: registry' http://localhost/v1/_ping | python -m json.tool"
    [ "$status" -eq 0 ]
}

@test "We should be able to push images to the private registry" {
    #
    # Build a custom Docker image using "scratch" as a base image. This will
    # result in our image being very small which will make for a fast test.
    #
    mkdir -p /tmp/docker-build
    cat << EOF > /tmp/docker-build/test-file
This is a test file to go into our container.
EOF
    cat << EOF > /tmp/docker-build/Dockerfile
FROM scratch
COPY test-file /test.txt
EOF
    run docker build \
        --tag=registry.yourdomain.local/test-ansible-package-caching-proxy \
        /tmp/docker-build
    [ "$status" -eq 0 ]
    run docker push registry.yourdomain.local/test-ansible-package-caching-proxy
    [ "$status" -eq 0 ]
}
