#!/bin/bash

source /opt/iprepd-nginx/etc/test-env

/usr/bin/redis-server --daemonize yes
while ! nc -z localhost 6379; do sleep 0.1; done

nohup /root/go/bin/iprepd -c /opt/iprepd-nginx/etc/iprepd.yaml >/dev/null 2>&1 &
while ! nc -z localhost 8080; do sleep 0.1; done

(cd /opt/iprepd-nginx/test && pytest -s)
