# iprepd-nginx module

`iprepd-nginx` is an openresty module for integrating with [iprepd](https://github.com/mozilla-services/iprepd).

You can use the example configuration in this repo for a standalone proxy or install using [opm](https://github.com/openresty/opm)
and integrate it yourself.

*Note:* If nginx is behind a load balancer, make sure to use something like
[ngx_http_realip_module](https://nginx.org/en/docs/http/ngx_http_realip_module.html).


## Installation

Install using [opm](https://github.com/openresty/opm)

```
opm get mozilla-services/iprepd-nginx
```

## Example

Note: Check out `/etc` in this repo for a working example.

```
init_by_lua_block {
  client = require("resty.iprepd").new({
    url = os.getenv("IPREPD_URL"),
    api_key = os.getenv("IPREPD_API_KEY"),
    threshold = tonumber(os.getenv("IPREPD_REPUTATION_THRESHOLD")),
    cache_ttl = os.getenv("IPREPD_CACHE_TTL"),
    timeout = tonumber(os.getenv("IPREPD_TIMEOUT")) or 10,
    cache_errors = tonumber(os.getenv("IPREPD_CACHE_ERRORS")),
    statsd_host = os.getenv("STATSD_HOST") or nil,
    statsd_port = tonumber(os.getenv("STATSD_PORT")) or 8125,
    statsd_max_buffer_count = tonumber(os.getenv("STATSD_MAX_BUFFER_COUNT")) or 100,
    statsd_flush_timer = tonumber(os.getenv("STATSD_FLUSH_TIMER")) or 5,
    dont_block = tonumber(os.getenv("DONT_BLOCK")) or 0,
    verbose = tonumber(os.getenv("VERBOSE")) or 0,
    whitelist = {},
  })
}

init_worker_by_lua_block {
  client:config_flush_timer()
}

server {
  listen       80;
  root         /dev/null;
  error_page   500 502 503 504  /50x.html;

  location = /50x.html {
    root  /usr/local/openresty/nginx/html/;
  }

  location = /health {
    return 200;
    access_log off;
  }

  set_by_lua_block $backend { return os.getenv("backend") }

  location / {
    proxy_set_header "X-Forwarded-Port" $server_port;
    proxy_set_header "X-Forwarded-For" $proxy_add_x_forwarded_for;
    proxy_set_header "X-Real-IP" $remote_addr;
    proxy_set_header "Host" $host;
    proxy_pass $backend;

    access_by_lua_block {
      client:check(ngx.var.remote_addr)
    }

    log_by_lua_block {
      if client.statsd then
        client.statsd.set("iprepd.ips_seen", ngx.var.remote_addr)
      end
    }
  }
}
```

### Configuration of the client

#### `threshold` parameter

The `threshold` value in the client is the numerical value inbetween 0 and 100 where clients will be blocked if their
IP's reputation in iprepd is below this value.

What you will want this value to be set to will be highly contextual to your application and environment, with considerations
of what kind of violations exist, how likely a client is to activate these violations, how often a client will retry, etc.

A decent value to start at is `50`, but you will want to make sure this is tested along side the implemented iprepd
violations for your environment.

#### Example

```lua
-- Parameters within options:
--  Required parameters:
--    api_key - An active API key for authenticating to iprepd
--    threshold - The reputation threshold, where IP's with a reputation below this number will
--                be blocked. There is no default for this, as it will be application specific,
--                but as described above 50 is a good starting place.
--
--  Optional parameters:
--    url - The base URL to iprepd (defaults to "http://localhost:8080/")
--    timeout - The timeout for making requests to iprepd in milliseconds (defaults to 10)
--    cache_ttl - The iprepd response cache ttl in seconds (defaults to 30)
--    cache_buffer_count - Max number of entries allowed in the cache. (defaults to 200)
--    cache_errors - Enables (1) or disables (0) caching errors. Caching errors is a good
--                   idea in production, as it can reduce the average additional latency
--                   caused by this module if anything goes wrong with the underlying
--                   infrastructure. (defaults to disabled)
--    statsd_host - Host of statsd collector. Setting this will enable statsd metrics collection
--    statsd_port - Port of statsd collector. (defaults to 8125)
--    statsd_max_buffer_count - Max number of metrics in buffer before metrics should be submitted
--                              to statsd (defaults to 100)
--    statsd_flush_timer - Interval for attempting to flush the stats in seconds. (defaults to 5)
--    dont_block - Enables (1) or disables (0) not blocking within nginx by returning
--                 a 403. (defaults to disabled)
--    verbose - Enables (1) or disables (0) verbose logging. Messages are logged with a
--              severity of "ERROR" so that nginx log levels do not need to be changed. (defaults
--              to disabled)
--    whitelist - List of whitelisted IP's and IP CIDR's. (defaults to empty)
--
client = require("resty.iprepd").new({
  api_key = os.getenv("IPREPD_API_KEY"),
  threshold = 50,
  url = "http://127.0.0.1:8080",
  timeout = 10,
  cache_ttl = 30,
  cache_buffer_count = 1000,
  cache_errors = 1,
  statsd_host = "127.0.0.1",
  statsd_port = 8125,
  statsd_max_buffer_count = 100,
  statsd_flush_timer = 10,
  dont_block = 0,
  verbose = 0,
  whitelist = {"127.0.0.1", "10.10.10.0/24", "192.168.0.0/16"}
})
```

## Running locally

Create a `.env` file in this repo with the needed environment variables (documentaion below).

Then run:
```
$ make build
$ make run_dev
```

Then you will be able to hit this proxy with: `curl http://localhost:80`

### Environment Variables for Dev

#### Note:

Quotations in env vars matter with nginx. Don't use them if you are using `--env-file` in Docker.

```
# required
backend=http://<>               # URL to proxy to
IPREPD_URL=http://<>            # iprepd url
IPREPD_API_KEY="api-key"        # iprepd api key
IPREPD_REPUTATION_THRESHOLD=50  # iprepd reputation threshold, block all IP's with a reputation below the threshold

#
# optional
#
IPREPD_TIMEOUT=10
IPREPD_CACHE_TTL=30
IPREPD_CACHE_ERRORS=0
STATSD_HOST=127.0.0.1
STATSD_PORT=8125
STATSD_MAX_BUFFER_COUNT=200
STATSD_FLUSH_TIMER=2
DONT_BLOCK=0
```
