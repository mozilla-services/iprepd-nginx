# iprepd-nginx module

`iprepd-nginx` is an openresty module for integrating with [iprepd](https://github.com/mozilla-services/iprepd).

You can use the example configuration in this repo for a standalone proxy or install using [opm](https://github.com/openresty/opm)
and integrate it yourself.

*Note:* If nginx is behind a load balancer, make sure to use something like
[ngx_http_realip_module](https://nginx.org/en/docs/http/ngx_http_realip_module.html).


## Installation

Install using [opm](https://github.com/openresty/opm)

```
opm get ajvb/iprepd-nginx
```

## Example

Note: Check out `/etc` in this repo for a working example.

```
init_by_lua_block {
  client = require("resty.iprepd").new({
    url = os.getenv("IPREPD_URL") or "http://127.0.0.1:8080",
    api_key = os.getenv("IPREPD_API_KEY"),
    cache_ttl = os.getenv("IPREPD_CACHE_TTL") or 30,
    threshold = tonumber(os.getenv("IPREPD_REPUTATION_THRESHOLD")),
    timeout = tonumber(os.getenv("IPREPD_TIMEOUT")) or 10,
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
IPREPD_TIMEOUT=10  # iprepd client timeout in milliseconds (default 10ms)
IPREPD_CACHE_TTL=60 # iprepd response cache ttl in seconds (default 30s)
```
