IMAGE_NAME	:= "iprepd-nginx"

# Build default docker image
build:
	docker build -t $(IMAGE_NAME) .

# Test iprepd-nginx using built image
test:
	docker run -ti --rm \
		--entrypoint /opt/iprepd-nginx/test/test.sh $(IMAGE_NAME)

# Test iprepd-nginx, override image installed iprepd-nginx Lua files, tests, and
# nginx configuration; useful for testing local modifications
test_dev:
	docker run -ti --rm \
		-v $(shell pwd)/etc/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
		-v $(shell pwd)/etc/conf.d:/usr/local/openresty/nginx/conf/conf.d \
		-v $(shell pwd)/lib/resty/iprepd.lua:/usr/local/openresty/site/lualib/resty/iprepd.lua \
		-v $(shell pwd)/lib/resty/statsd.lua:/usr/local/openresty/site/lualib/resty/statsd.lua \
		-v $(shell pwd)/etc/testconf/rl/conf.d:/opt/iprepd-nginx/etc/testconf/rl/conf.d \
		-v $(shell pwd)/test/test_module.py:/opt/iprepd-nginx/test/test_module.py \
		--entrypoint /opt/iprepd-nginx/test/test.sh $(IMAGE_NAME)

# Run development instance, overriding image installed iprepd-nginx Lua files and
# nginx configuration; requires a .env file in the repository root
run_dev:
	docker run -ti --rm \
		--env-file=.env \
		-v $(shell pwd)/etc/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
		-v $(shell pwd)/etc/conf.d:/usr/local/openresty/nginx/conf/conf.d \
		-v $(shell pwd)/lib/resty/iprepd.lua:/usr/local/openresty/site/lualib/resty/iprepd.lua \
		-v $(shell pwd)/lib/resty/statsd.lua:/usr/local/openresty/site/lualib/resty/statsd.lua \
		--network="host" $(IMAGE_NAME)

.PHONY: build run_dev test test_dev
