#!/usr/bin/env python3

import socketserver
import http.server
import subprocess
import json
import requests
import time
import pytest
import threading
import os

class openresty_runner(threading.Thread):
    cmd = ['/usr/bin/openresty', '-g', 'daemon off;']

    def run(self):
        self.proc = subprocess.Popen(self.cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)

    def stop(self):
        self.proc.terminate()
        out, err = self.proc.communicate()
        return out, err

    def begin(self):
        self.start()
        # Wait until the daemon is up and running
        while True:
            try:
                r = requests.get('http://127.0.0.1/health')
                break
            except Exception as e:
                time.sleep(0.1)

    def __init__(self):
        threading.Thread.__init__(self)

class iprepd_mock(threading.Thread):
    mode_delay = 1
    mode_error = 2
    mode_ok = 3

    def run(self):
        self.httpd.serve_forever()

    def shutdown(self):
        self.httpd.shutdown()

    def __init__(self):
        threading.Thread.__init__(self)
        self.mode = self.mode_error
        socketserver.ThreadingTCPServer.allow_reuse_address = True
        self.httpd = socketserver.ThreadingTCPServer(('', 8081), http_handler)

# XXX This global and specifically the use of the mode field to toggle behavior isn't
# great and should be replaced with something more precise.
iprepd_mock_thread = None

class http_handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if iprepd_mock_thread.mode == iprepd_mock.mode_error:
            self.send_response(500)
            self.end_headers()
        elif iprepd_mock_thread.mode == iprepd_mock.mode_delay:
            time.sleep(5)
            self.send_response(404)
            self.end_headers()
        elif iprepd_mock_thread.mode == iprepd_mock.mode_ok:
            buf = json.dumps({
                'object': '127.0.0.1',
                'type': 'ip',
                'reputation': 25
            })
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(buf.encode(encoding='utf_8'))

@pytest.fixture(scope='session', autouse=True)
def start_http(request):
    global iprepd_mock_thread
    iprepd_mock_thread = iprepd_mock()
    request.addfinalizer(stop_http)
    iprepd_mock_thread.start()

def stop_http():
    iprepd_mock_thread.shutdown()

@pytest.fixture
def openresty():
    # Reset IP reputation as part of fixture before test
    update_reputation(100, '127.0.0.1')
    return openresty_runner()

def update_reputation(rep, ip):
    body = { 'object': ip, 'type': 'ip', 'reputation': rep }
    headers = { 'content-type': 'application/json',
        'authorization': 'APIKey ' + os.environ['IPREPD_API_KEY'] }
    requests.put(os.environ['IPREPD_URL'] + '/type/ip/127.0.0.1',
        json=body, headers=headers)

def simple_request():
    return requests.get('http://127.0.0.1/iprepd_ping')

def test_simple_request(openresty):
    openresty.begin()
    ret = simple_request()
    _, err = openresty.stop()
    assert ret.status_code == 200
    assert ret.text == 'pong\n'
    assert len(err) == 0

def test_bad_apikey(openresty):
    oldkey = os.environ['IPREPD_API_KEY']
    os.environ['IPREPD_API_KEY'] = 'invalid'
    openresty.begin()
    ret = simple_request()
    _, err = openresty.stop()
    assert ret.status_code == 200
    assert 'iprepd responded with a 401 http status code' in str(err)
    os.environ['IPREPD_API_KEY'] = oldkey

def test_reputation_fail(openresty):
    update_reputation(0, '127.0.0.1')
    os.environ['BLOCKING_MODE'] = '1'
    openresty.begin()
    ret = simple_request()
    _, err = openresty.stop()
    assert ret.status_code == 429
    assert '127.0.0.1 rejected with a reputation of 0' in str(err)
    del os.environ['BLOCKING_MODE']

def test_serial_range(openresty):
    update_reputation(0, '127.0.0.1')
    os.environ['BLOCKING_MODE'] = '1'
    openresty.begin()
    for _ in range(250):
        ret = simple_request()
        assert ret.status_code == 429
    _, err = openresty.stop()
    del os.environ['BLOCKING_MODE']

def test_reputation_above(openresty):
    update_reputation(51, '127.0.0.1')
    os.environ['BLOCKING_MODE'] = '1'
    openresty.begin()
    ret = simple_request()
    _, err = openresty.stop()
    assert ret.status_code == 200
    assert len(err) == 0
    del os.environ['BLOCKING_MODE']

def test_cache_ttl(openresty):
    os.environ['BLOCKING_MODE'] = '1'
    os.environ['IPREPD_CACHE_TTL'] = '3'
    openresty.begin()
    ret = simple_request()
    assert ret.status_code == 200
    update_reputation(0, '127.0.0.1')
    ret = simple_request()
    # Should still be in cache as OK
    assert ret.status_code == 200
    # Sleep to let the cache entry expire
    time.sleep(4)
    ret = simple_request()
    assert ret.status_code == 429
    _, err = openresty.stop()
    assert len(str(err).split('\n')) == 1
    del os.environ['BLOCKING_MODE']
    del os.environ['IPREPD_CACHE_TTL']

def test_request_timeout(openresty):
    # Make use of simulated inoperable service
    oldurl = os.environ['IPREPD_URL']
    os.environ['IPREPD_URL'] = 'http://127.0.0.1:8081'
    iprepd_mock_thread.mode = iprepd_mock.mode_delay
    openresty.begin()
    ret = simple_request()
    _, err = openresty.stop()
    assert ret.status_code == 200
    assert 'lua tcp socket read timed out' in str(err)
    os.environ['IPREPD_URL'] = oldurl

def test_cache_errors_disabled(openresty):
    os.environ['BLOCKING_MODE'] = '1'
    # Make use of simulated inoperable service
    oldurl = os.environ['IPREPD_URL']
    os.environ['IPREPD_URL'] = 'http://127.0.0.1:8081'
    iprepd_mock_thread.mode = iprepd_mock.mode_error
    openresty.begin()
    ret = simple_request()
    # Should have resulted in an error, so we'd get a 200 back
    assert ret.status_code == 200
    iprepd_mock_thread.mode = iprepd_mock.mode_ok
    ret = simple_request()
    # Error would not have been cached so should result in new check
    assert ret.status_code == 429
    _, err = openresty.stop()
    os.environ['IPREPD_URL'] = oldurl
    del os.environ['BLOCKING_MODE']

def test_cache_errors_enabled(openresty):
    os.environ['BLOCKING_MODE'] = '1'
    os.environ['IPREPD_CACHE_ERRORS'] = '1'
    # Make use of simulated inoperable service
    oldurl = os.environ['IPREPD_URL']
    os.environ['IPREPD_URL'] = 'http://127.0.0.1:8081'
    iprepd_mock_thread.mode = iprepd_mock.mode_error
    openresty.begin()
    ret = simple_request()
    # Should have resulted in an error, so we'd get a 200 back
    assert ret.status_code == 200
    iprepd_mock_thread.mode = iprepd_mock.mode_ok
    ret = simple_request()
    # Should have been cached so will still get a 200
    assert ret.status_code == 200
    _, err = openresty.stop()
    os.environ['IPREPD_URL'] = oldurl
    del os.environ['BLOCKING_MODE']
    del os.environ['IPREPD_CACHE_ERRORS']
