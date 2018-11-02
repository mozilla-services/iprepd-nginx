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
    url = os.getenv("IPREPD_URL") or "http://127.0.0.1:8080",
    api_key = os.getenv("IPREPD_API_KEY"),
    threshold = tonumber(os.getenv("IPREPD_REPUTATION_THRESHOLD")),
    cache_ttl = os.getenv("IPREPD_CACHE_TTL"),
    timeout = tonumber(os.getenv("IPREPD_TIMEOUT")),
    cache_errors = tonumber(os.getenv("IPREPD_CACHE_ERRORS")),
  })
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

  # Default location, will enforce authentication there
  location / {
    proxy_set_header "X-Forwarded-Port" $server_port;
    proxy_set_header "X-Forwarded-For" $proxy_add_x_forwarded_for;
    proxy_set_header "X-Real-IP" $remote_addr;
    proxy_set_header "Host" $host;
    access_by_lua_block {
      client:check(ngx.var.remote_addr)
    }
    proxy_pass $backend;
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
--    cache_ttl - The iprepd response cache ttl in seconds (defaults to 30)
--    timeout - The timeout for making requests to iprepd in milliseconds (defaults to 10)
--    cache_errors - Enables (1) or disables (0) caching errors. Caching errors is a good
--                   idea in production, as it can reduce the average additional latency
--                   caused by this module if anything goes wrong with the underlying
--                   infrastructure. (defaults to disabled)
--
client = require("resty.iprepd").new({
  url = "http://127.0.0.1:8080",
  api_key = os.getenv("IPREPD_API_KEY"),
  threshold = 50,
  cache_ttl = 30,
  timeout = 10,
  cache_errors = 1,
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

### Environment Variables

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
IPREPD_TIMEOUT=10  # iprepd client timeout in milliseconds (default is 10ms)
IPREPD_CACHE_TTL=60 # iprepd response cache ttl in seconds (default is 30s)
IPREPD_CACHE_ERRORS=1 # enables caching iprepd non-200 responses (1 enables, 0 disables, default is 0)
```
