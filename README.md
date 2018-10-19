# iprepd nginx proxy

This repo contains the needed pieces to build a container that runs an nginx (openresty)
proxy that integrates with [iprepd](https://github.com/mozilla-services/iprepd).

It will check if the IP exists in iprepd, and if it does it will check the reputation against
the configured `IPREPD_REPUTATION_THRESHOLD` and will return with a `403` if it's reputation
is above the threshold.

## Setup

### Running locally

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
IPREPD_REPUTATION_THRESHOLD=50  # iprepd reputation threshold to block on

#
# optional
#
IPREPD_TIMEOUT=.05  # iprepd client timeout (default 10ms)
IPREPD_CACHE_TTL=60 # iprepd response cache ttl (default 30s)
```

## TODO:

- [ ] Convert to [opm](https://github.com/openresty/opm#readme) package
