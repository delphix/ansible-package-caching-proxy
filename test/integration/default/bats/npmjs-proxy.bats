#!/usr/bin/env bats
#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

#
# Test the npmjs-proxy app, Sinopia.
#

# A node package to attempt to install through our proxy.
NODE_PACKAGE=statsd

setup() {
    apt-get install -y curl npm
    npm set registry http://localhost:4873/
}

@test "Accessing the npmjs vhost should return HTTP 200" {
    run curl -sS -I -H 'Host: npm' http://localhost
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 200 OK" ]]
}

@test "Accessing the npmjs-proxy vhost should reveal the back-end app's name" {
    run curl -sS -I -H 'Host: npm' http://localhost
    [ "$status" -eq 0 ]
    [[ "$output" =~ "X-Powered-By: Sinopia" ]]
}

@test "Downloading & installing a Node package through our npmjs proxy should succeed" {
    run npm install $NODE_PACKAGE
    [ "$status" -eq 0 ]
    echo $output
    regex="npm http (200|304) http://localhost:4873/$NODE_PACKAGE"
    [[ "$output" =~ $regex ]]
}

#
# Kill the Sinopia container and restart it with its networking broken by
# giving it bad DNS server settings. With npmjs.org unavailable but our
# cache already populated, the download of the previous Node package should
# still succeed.
#

@test "We should be able to install cached Node packages when the Sinopia container's networking backend is broken" {
    docker kill sinopia
    docker rm sinopia
    docker run -d --name sinopia -p 4873:4873 --dns=1.1.1.1 -v /opt/npmjs-server:/sinopia/storage rnbwd/sinopia
    # Give the app a few seconds to load
    sleep 5

    run npm install $NODE_PACKAGE
    [ "$status" -eq 0 ]
    regex="npm http (200|304) http://localhost:4873/$NODE_PACKAGE"
    [[ "$output" =~ $regex ]]

    # restart the container with networking un-broken
    docker kill sinopia
    docker rm sinopia
    docker run -d --name sinopia -p 4873:4873 -v /opt/npmjs-server:/sinopia/storage rnbwd/sinopia
}
