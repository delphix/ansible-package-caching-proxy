#!/usr/bin/env bats
#
# Copyright (c) 2015 by Delphix. All rights reserved.
#

#
# Test devpi (PyPI proxy).
#

setup() {
    apt-get install -y curl python-virtualenv
}

@test "Accessing the devpi server on port 3141 should return a valid JSON response" {
    run bash -c "curl -sSq http://localhost:3141/ | python -m json.tool"
    [ "$status" -eq 0 ]
}

@test "Accessing the devpi server via the nginx vhost should return a valid JSON response" {
    run bash -c "curl -sSq -H 'Host: devpi' http://localhost/ | python -m json.tool"
    [ "$status" -eq 0 ]
}

@test "Downloading a Python package via our PyPI proxy should succeed" {
    VENV_PATH="$(mktemp -d /tmp/venv.XXXX)"
    virtualenv $VENV_PATH
    run bash -c "source $VENV_PATH/bin/activate && pip install -i http://localhost:3141/root/pypi/ django"
    [ "$status" -eq 0 ]
}

#
# Kill the devpi container and restart it with its networking broken by
# giving it bad DNS server settings. With pypi.python.org unavailable but our
# cache already populated, the download of the previous Python package should
# still succeed.
#

@test "We should still be able to install Python packages when the devpi contianer's backend is broken" {
    docker kill devpi
    docker rm devpi
    docker run -d --name devpi -p 3141:3141 --dns=1.1.1.1 -v /opt/devpi-server:/mnt scrapinghub/devpi:latest
    # give the app a few seconds to load
    sleep 3

    VENV_PATH="$(mktemp -d /tmp/venv.XXXX)"
    virtualenv $VENV_PATH
    source $VENV_PATH/bin/activate
    run pip install -i http://localhost:3141/root/pypi/ django
    [ "$status" -eq 0 ]
    docker kill devpi
    docker rm devpi
}
