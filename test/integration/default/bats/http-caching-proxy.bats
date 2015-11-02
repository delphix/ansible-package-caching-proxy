#!/usr/bin/env bats
#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

#
# Test the nginx HTTP caching proxy.
#

HTTP_PROXY_URL="http://localhost:1080"

setup() {
    apt-get install -y curl
}

#
# Hit google.com thru the proxy. This should always return a MISS because
# google.com presumably has the HTTP header for "Cache-Control: private",
# telling proxies to never cache. The "X-Cache-Status" header is a custom header
# that our nginx vhost is adding for us to be able to debug the cache status :)
#
@test "Accessing http://www.google.com through our proxy should always return a cache miss" {
    run curl -sI http://www.google.com
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Cache-Control: private" ]]

    for i in $(seq 1 5); do
        run curl -sSq -I --proxy $HTTP_PROXY_URL http://www.google.com/
        [ "$status" -eq 0 ]
        [[ "$output" =~ "X-Cache-Status: MISS" ]]
    done
}

#
# Download a minimal installer for Basic Linux (~2MB). The first time should
# download successfully with a cache miss. The second time should download
# successfully with a cache hit.
#

PROTOCOL="http"
PROTOCOL_RELATIVE_DOWNLOAD_URL="distro.ibiblio.org/baslinux/bl3-50fd.zip"
ISO_URL="$PROTOCOL://$PROTOCOL_RELATIVE_DOWNLOAD_URL"

@test "Downloading a file that is not in the cache should result in a cache miss" {
    # Clear any preexisting file from the cache by hitting the "/purge" location.
    run curl -sSD - -o /dev/null http://localhost:1080/purge/$PROTOCOL_RELATIVE_DOWNLOAD_URL
    [ "$status" -eq 0 ]

    run curl --proxy $HTTP_PROXY_URL -sSD - -o /dev/null $ISO_URL
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 200 OK" ]]
    [[ "$output" =~ "X-Cache-Status: MISS" ]]
}

@test "Downloading a file that is in the cache should result in a cache hit" {
    run curl --proxy $HTTP_PROXY_URL -sSD - -o /dev/null $ISO_URL
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 200 OK" ]]
    regex="X-Cache-Status: HIT"
    [[ "$output" =~ $regex ]]
}

@test "Setting the header 'X-Refresh: true' should result in a bypass of the cache" {
    run curl --proxy $HTTP_PROXY_URL -H 'X-Refresh: true' -sSD - -o /dev/null $ISO_URL
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 200 OK" ]]
    [[ "$output" =~ "X-Cache-Status: BYPASS" ]]
}

@test "Trying to purge when it's not in the cache should return 404" {
    # Clear the file from the cache by hitting the "/purge" location.
    run curl -sSD - -o /dev/null \
    http://localhost:1080/purge/$PROTOCOL_RELATIVE_DOWNLOAD_URL
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 200 OK" ]]

    run curl -sSD - -o /dev/null \
    http://localhost:1080/purge/$PROTOCOL_RELATIVE_DOWNLOAD_URL
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 404 Not Found" ]]
}

@test "Downloading the file again after purging from the cache should yield a cache miss" {
    run curl --proxy $HTTP_PROXY_URL -sSD - -o /dev/null $ISO_URL
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HTTP/1.1 200 OK" ]]
    [[ "$output" =~ "X-Cache-Status: MISS" ]]
}
