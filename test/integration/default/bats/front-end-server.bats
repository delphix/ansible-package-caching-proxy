#!/usr/bin/env bats
#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

setup() {
    apt-get install -y curl
}

@test "The front-end serer's root url should return http 204" {
    run curl -sSD - http://localhost/
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 204 No Content" ]]
}

@test "The front-end server's /_status location should return statistics from our web server" {
    run curl -sSD - http://localhost/_status

    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 200 OK" ]]
    regex="Active connections: [[:digit:]]+"
    [[ "$output" =~ $regex ]]
}
