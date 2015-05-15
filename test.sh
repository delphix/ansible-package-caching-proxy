#!/bin/bash
#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

set -x
set -o pipefail

export PS4='Line $LINENO: '

PROGNAME=$(basename $0)

function error_exit
{
    echo "$PROGNAME: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

trap error_exit ERR SIGHUP SIGINT SIGTERM

if [[ ! -f requirements.txt ]]; then
    echo "Error: $PROGNAME needs to be run from the top level directory where requirements.txt lives"
    exit 2
fi

#
# Install Ansible dependencies and create our VM. The "Vagrantfile" will
# automatically run Ansible in the VM to configure the web services within it.
#

# We need our Ansible requirements installed into "roles/" for testing.
if [[ ! -d roles ]]; then
    mkdir -pv roles
    ansible-galaxy install -p roles/ -r requirements.txt
    ansible-galaxy install -p roles angstwad.docker_ubuntu
fi

#
# Run "vagrant" to provision the VM. Once the VM is up we can run tests
# against it. We need to add the "vagrant" user to the "docker" group
# in order to be able run "docker" commands later.
#
vagrant up
vagrant provision
vagrant ssh -- sudo usermod -G docker vagrant

# A temp file for us to store our test output.
TEST_OUTPUT=$(mktemp /tmp/test.XXXXX)

#
# Test the default server block (vhost)
#

# The root of the default vhost should return "HTTP 204 No Content"
curl --fail -sSD - http://localhost:8080/ >$TEST_OUTPUT
grep "HTTP/1.1 204 No Content" $TEST_OUTPUT >/dev/null

# The "/_status" location should return statistics from our web server.
curl --fail -sSD - http://localhost:8080/_status >$TEST_OUTPUT
grep "HTTP/1.1 200 OK" $TEST_OUTPUT >/dev/null
grep -E "Active connections: \d+" $TEST_OUTPUT >/dev/null

#
# Test the apt-cacher-ng app.
#

# Accessing the vhost should load the configuration page for Apt-Cacher-NG.
curl -sSq -H 'Host: apt-cache' http://localhost:8080/ | \
    grep Apt-Cacher-NG >/dev/null

PACKAGE_SERVER=ftp.debian.org/debian
# Hitting the apt-cacher proxy on the proxy port should succeed.
curl --fail -sS http://localhost:3142/$PACKAGE_SERVER >/dev/null

# The previous command that hit ftp.debian.org should have placed some
# files in the cache.
vagrant ssh -- ls -l /opt/apt-cache/$PACKAGE_SERVER

#
# Test devpi (PyPI proxy).
#

# Accessing the devpi server on port 3141 should return a valid JSON response.
curl --fail -sSq http://localhost:3141/ | python -m json.tool >/dev/null

# Accessing the devpi server via the nginx vhost should return a valid
# JSON response.
curl --fail -sSq -H 'Host: devpi' http://localhost:8080/ | \
    python -m json.tool >/dev/null

# Download a Python package via our PyPI proxy.
VENV_PATH="$(mktemp -d /tmp/venv.XXXX)"
virtualenv $VENV_PATH
(source $VENV_PATH/bin/activate; pip install -i http://localhost:3141/root/pypi/ django)

#
# Kill the devpi container and restart it with its networking broken by
# giving it bad DNS server settings. With pypi.python.org unavailable but our
# cache already populated, the download of the previous Python package should
# still succeed.
#
vagrant ssh -- docker kill devpi
vagrant ssh -- docker rm devpi
vagrant ssh -- docker run -d --name devpi -p 3141:3141 --dns=1.1.1.1 \
    -v /opt/devpi-server:/mnt scrapinghub/devpi:latest
VENV_PATH="$(mktemp -d /tmp/venv.XXXX)"
virtualenv $VENV_PATH
(source $VENV_PATH/bin/activate; pip install -i http://localhost:3141/root/pypi/ django)
vagrant ssh -- docker kill devpi
vagrant ssh -- docker rm devpi

#
# Test the nginx HTTP caching proxy.
#

HTTP_PROXY_URL="http://localhost:1080"

#
# Hit google.com thru the proxy. This should always return a MISS because
# google.com presumably has the HTTP header for "Cache-Control: private",
# telling proxies to never cache. The "X-Cache-Status" header is a custom header
# that our nginx vhost is adding for us to be able to debug the cache status :)
#
curl --fail -sI http://www.google.com | grep "Cache-Control: private" >/dev/null

for i in $(seq 1 5); do
    curl --fail -sSq -I --proxy $HTTP_PROXY_URL http://www.google.com/ | \
        grep "X-Cache-Status: MISS" >/dev/null
    sleep 1
done

#
# Download a minimal installer for Basic Linux (~2MB). The first time should
# download successfully with a cache miss. The second time should download
# successfully with a cache hit.
#
PROTOCOL="http"
PROTOCOL_RELATIVE_DOWNLOAD_URL="distro.ibiblio.org/baslinux/bl3-50fd.zip"
ISO_URL="$PROTOCOL://$PROTOCOL_RELATIVE_DOWNLOAD_URL"

# Clear any preexisting file from the cache by hitting the "/purge" location.
curl -sSD - -o /dev/null \
    http://localhost:1080/purge/$PROTOCOL_RELATIVE_DOWNLOAD_URL >$TEST_OUTPUT

curl --fail --proxy $HTTP_PROXY_URL -sSD - -o /dev/null $ISO_URL >$TEST_OUTPUT
grep "HTTP/1.1 200 OK" $TEST_OUTPUT >/dev/null
grep "X-Cache-Status: MISS" $TEST_OUTPUT >/dev/null

curl --fail --proxy $HTTP_PROXY_URL -sSD - -o /dev/null $ISO_URL >$TEST_OUTPUT
grep "HTTP/1.1 200 OK" $TEST_OUTPUT >/dev/null
grep "X-Cache-Status: HIT" $TEST_OUTPUT >/dev/null

# Setting the header "X-Refresh: true" should result in a bypass of the cache.
curl --fail --proxy $HTTP_PROXY_URL -H 'X-Refresh: true' -sSD - -o /dev/null \
    $ISO_URL >$TEST_OUTPUT
grep "HTTP/1.1 200 OK" $TEST_OUTPUT >/dev/null
grep "X-Cache-Status: BYPASS" $TEST_OUTPUT >/dev/null

# Clear the file from the cache by hitting the "/purge" location.
curl --fail -sSD - -o /dev/null \
    http://localhost:1080/purge/$PROTOCOL_RELATIVE_DOWNLOAD_URL >$TEST_OUTPUT
grep "HTTP/1.1 200 OK" $TEST_OUTPUT >/dev/null

# Trying to purge when it's not in the cache should return 404.
curl -sSD - -o /dev/null \
    http://localhost:1080/purge/$PROTOCOL_RELATIVE_DOWNLOAD_URL >$TEST_OUTPUT
grep "HTTP/1.1 404 Not Found" $TEST_OUTPUT >/dev/null

# Downloading the file again after purging from the cache should yield a cache
# miss.
curl --fail --proxy $HTTP_PROXY_URL -sSD - -o /dev/null \
    $ISO_URL >$TEST_OUTPUT
grep "HTTP/1.1 200 OK" $TEST_OUTPUT >/dev/null
grep "X-Cache-Status: MISS" $TEST_OUTPUT >/dev/null

#
# Test the Docker Registry server.
#

curl --fail -sSq -H 'Host: registry' http://localhost:8080/ | \
    grep "docker-registry server" >/dev/null
curl --fail -sSq -H 'Host: registry' http://localhost:8080/_ping | \
    python -m json.tool >/dev/null
curl --fail -sSq -H 'Host: registry' http://localhost:8080/v1/_ping | \
    python -m json.tool >/dev/null

#
# Test the yum repo vhost.
#

curl --fail -sSq -I -H 'Host: yum' http://localhost:8080/ >$TEST_OUTPUT
grep "HTTP/1.1 200 OK" $TEST_OUTPUT >/dev/null

echo All tests completed successfully.
