IMAGE_NAME	:= "iprepd-nginx"

# Build docker images for testing and prod
build:
	docker-compose build --no-cache integration-test
	docker-compose build iprepd-nginx

# Build test image
build_test:
	docker-compose build --no-cache test-client

# Run tests from within iprepd-nginx integration stage container
# Copy configs for fixtures so CI doesn't need volume mount
integration_test:
	docker-compose down -v
	docker-compose up --no-start iprepd
	docker cp ./test/configs/fixtures/iprepd/iprepd.yaml iprepd_app:/app/config/iprepd.yaml
	docker-compose run integration-test

# Run all smoke test against production image
# Copy configs for fixtures so CI doesn't need volume mount
smoke_test:
	docker-compose down -v
	docker-compose up --no-start iprepd backend
	docker cp ./test/configs/fixtures/iprepd/iprepd.yaml iprepd_app:/app/config/iprepd.yaml
	docker cp ./test/configs/fixtures/backend/index.html backend:/usr/share/nginx/html/index.html
	docker-compose up -d iprepd-nginx
	docker-compose run test-client

# Run development environment, overriding image installed iprepd-nginx Lua files and config
# Environment contains: iprepd-nginx, iprepd, redis, backend
run_dev_env:
	docker-compose down -v
	docker-compose up iprepd-nginx

# Run development instance, overriding image installed iprepd-nginx Lua files and
# nginx configuration; requires a .env file in the repository root
# only container for iprepdnginx
run_dev:
	docker run -ti --rm \
		--env-file=.env \
		-v $(shell pwd)/etc/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
		-v $(shell pwd)/etc/conf.d:/usr/local/openresty/nginx/conf/conf.d \
		-v $(shell pwd)/lib/resty/iprepd.lua:/usr/local/openresty/site/lualib/resty/iprepd.lua \
		-v $(shell pwd)/lib/resty/statsd.lua:/usr/local/openresty/site/lualib/resty/statsd.lua \
		--network="host" $(IMAGE_NAME)

.PHONY: build build_test integration_test run_dev run_dev_env smoke_test
