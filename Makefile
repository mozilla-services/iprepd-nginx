IMAGE_NAME	:= "iprepd-nginx"

build: Dockerfile
	docker build -t $(IMAGE_NAME) .

run_dev: Dockerfile
	docker run \
		--env-file=.env \
		-v $(shell pwd)/etc/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf \
		-v $(shell pwd)/etc/conf.d:/usr/local/openresty/nginx/conf/conf.d \
		--rm --network="host" -it $(IMAGE_NAME)

.PHONY: build run_dev
