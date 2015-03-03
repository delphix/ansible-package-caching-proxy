## Delphix - package-caching-proxy

Ansible role that installs and configures a variety of caching proxies and
artifact hosting web services.

Based on the [Docker Global Hack Day](https://www.docker.com/community/globalhackday)
entry, [Snakes on a Plane](https://github.com/hughdbrown/snakes-on-a-plane)
which was unfortunately never completed.

#### Why Is this Useful?

* When you have no Internet connectivity or are operating with bandwidth and
availability constraints, ex: On a plane or on a poor VPN connection.
* When your organization has remote offices/employees whose productivity would
benefit from having fast local copies of large binaries like ISOs, OVAs, or OS
packages.
* When your dev process depends on external dependencies from services that are
susceptible to outages, ex. [NPM](https://www.npmjs.com) or
[PyPI](https://pypi.python.org).
* When your dev process depends on third-party artifacts that are pinned to
certain versions and you want a local copy of those pinned dependencies in case
they become unavailable in the future.

#### Details

Installs the following services as server blocks (aka. virtual hosts) behind a
front-end [nginx](http://nginx.org) web server:

* [apt-cacher-ng](https://www.unix-ag.uni-kl.de/~bloch/acng/): A caching proxy
tailored to cache operating system packages for Debian-based distributions
* [devpi](http://doc.devpi.net): A PyPI mirror that is also capable of acting as
a private PyPI index for uploading of custom Python packages
* [docker registry](https://github.com/docker/docker-registry): A private Docker
registry
* [nginx HTTP caching proxy](http://nginx.com/resources/admin-guide/caching/): A
general purpose HTTP caching proxy.

#### Requirements & Dependencies
* Tested on Ansible 1.8
* A working installation of [Docker](https://www.docker.com).
[angstwad.docker_ubuntu](https://galaxy.ansible.com/list#/roles/292) is a great
Ansible role for this, but is not a declared dependency of this role in the
interest of not making this role overly opinionated.
* jdauphant.nginx ([Galaxy](https://galaxy.ansible.com/list#/roles/466)/
[GitHub](https://github.com/jdauphant/ansible-role-nginx))

#### Variables

```
apt_cache_server_enable: true
apt_cache_server_dir: /var/cache/apt-cacher-ng
apt_cache_server_port: 3142
apt_cache_server_vhost_name: "apt-cache apt-cache.yourdomain.local"

devpi_server_enable: true
devpi_server_dir: /opt/devpi-server
devpi_server_port: 3141
# password for the root user
devpi_server_password: 1234
devpi_server_vhost_name: "devpi devpi.yourdomain.local"

docker_registry_enable: true
docker_registry_dir: /opt/docker-registry
docker_registry_port: 5000
docker_registry_vhost_name: "registry registry.yourdomain.local"

nginx_caching_proxy_server_enable: true
nginx_caching_proxy_server_dir: /var/cache/nginx
# Port 1080 is the default for the SOCKS service
nginx_caching_proxy_server_port: 1080
nginx_caching_proxy_server_inactive: 3d
# "resolver" defaults to Google's DNS. If you want to cache private
# intranet resources, then you should set this to an internal DNS server.
nginx_caching_proxy_server_resolver: 8.8.8.8
# Max cache size on disk
nginx_caching_proxy_server_max_size: 100g
nginx_caching_proxy_server_proxy_cache_valid_codes: 200 301 302
nginx_caching_proxy_server_proxy_cache_valid_time: 3d
nginx_caching_proxy_server_vhost_name: "proxy proxy.yourdomain.local"
```

#### Examples

##### apt-cacher-ng

The easiest way to use the Apt caching proxy is to put a line like the following
into a file like `/etc/apt/apt.conf.d/02proxy`:
```
Acquire::http { Proxy "http://CacheServerIp:3142"; };
```

More details at:
[https://www.unix-ag.uni-kl.de/~bloch/acng/html/config-servquick.html#config-client](https://www.unix-ag.uni-kl.de/~bloch/acng/html/config-servquick.html#config-client)

##### Devpi
See tutorials at: [http://doc.devpi.net/latest/](http://doc.devpi.net/latest/)

##### Docker Registry
See documentation at:
[https://github.com/docker/docker-registry](https://github.com/docker/docker-registry)

##### Nginx HTTP Caching Proxy

Set your OS's HTTP proxy to be the caching proxy's virtual host. Details are
specific to your OS.

Useful information from the HTTP caching proxy can be found in custom headers
in the HTTP response. Ex:

```
# Interesting headers in HTTP responses
# ===
X-Cache-Status: MISS  # Indicates a cache miss
X-Cache-Status: HIT   # Indicates a cache hit

# The cache can be bypassed and re-populated by setting the custom header
# "X-Refresh: true" in the originating HTTP request
X-Cache-Status: BYPASS

# Items may be programmatically purged from the cache by performing
# a GET on the "/purge" location. Ex:
# Remove the file from the disk cache by hitting the "/purge" location
curl -sD - http://localhost:1080/purge/releases.ubuntu.com/14.04/ubuntu-14.04-server-amd64.template
...
HTTP/1.1 200 OK
```

##### Server Stats

Statistics from the front-end server are available through the "/_status"
location. Ex:

```
$ curl -s http://localhost:8080/_status
Active connections: 1
server accepts handled requests
 28 28 28
Reading: 0 Writing: 1 Waiting: 0
```

This can be used to gather web server statistics using an application like
[collectd](https://collectd.org/wiki/index.php/Plugin:nginx).

#### License

Apache License 2.0

#### Thanks
* The folks who conceived the
[Snakes on a Plane](https://github.com/hughdbrown/snakes-on-a-plane) Docker
Hack Day project.
* The Engineering Team at VMware, who proved this idea out by implementing a
similar set of caching proxy servers for their global remote offices in order
to improve developer productivity.

#### Feedback, bug-reports, requests, ...
Are [welcome](https://github.com/delphix/ansible-package-caching-proxy).
