FROM openresty/openresty:1.13.6.2-centos

RUN yum install -y epel-release && \
	yum update -y && \
	yum install -y git python3 redis nc && \
	curl -OL https://dl.google.com/go/go1.14.linux-amd64.tar.gz && \
	(cd /usr/local && tar -zxf /go1.14.linux-amd64.tar.gz) && \
	rm -f /go1.14.linux-amd64.tar.gz && \
	env GOPATH=/root/go /usr/local/go/bin/go get go.mozilla.org/iprepd && \
	env GOPATH=/root/go /usr/local/go/bin/go install go.mozilla.org/iprepd/cmd/iprepd && \
	pip3 install pytest requests && \
	opm get pintsized/lua-resty-http hamishforbes/lua-resty-iputils openresty/lua-resty-lrucache && \
	mkdir -p /opt/iprepd-nginx/{etc,test} && \
	groupadd nginx && useradd -g nginx --shell /bin/false nginx

# Install iprepd-nginx from the local branch in the image
COPY lib/resty/*.lua /usr/local/openresty/site/lualib/resty/

# Copy base OpenResty configuration
COPY etc/conf.d /usr/local/openresty/nginx/conf/conf.d/
COPY etc/nginx.conf /usr/local/openresty/nginx/conf/

# Copy objects used as part of testing
COPY etc/iprepd.yaml etc/test-env etc/iprepd-nginx-ping.txt \
	/opt/iprepd-nginx/etc/
COPY test/test.sh test/test_module.py /opt/iprepd-nginx/test/

EXPOSE 80
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/openresty", "-g", "daemon off;"]
