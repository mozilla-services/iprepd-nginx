#!/usr/bin/env python3

import json
import requests
import pytest
import socket
import os
import time
import logging

LOGGER = logging.getLogger(__name__)

def get_ip() -> str:
    return socket.gethostbyname(socket.gethostname())

def is_healthy() -> bool:
    url = os.environ['IPREPD_NGINX'] + '/health'

    try:
        r = requests.get(url)
        return r.status_code == 200
    except Exception:
        LOGGER.exception("Error during healthcheck")
        return False

def update_reputation(rep: int, ip: str):
    body = { 'object': ip, 'type': 'ip', 'reputation': rep }
    headers = { 'content-type': 'application/json',
        'authorization': 'APIKey ' + os.environ['IPREPD_API_KEY'] }
    r = requests.put(os.environ['IPREPD_URL'] + '/type/ip/' + ip,
        json=body, headers=headers)
    assert r.status_code == 200

def delete_reputation(ip:str):
    headers = { 'content-type': 'application/json',
        'authorization': 'APIKey ' + os.environ['IPREPD_API_KEY'] }
    r = requests.delete(os.environ['IPREPD_URL'] + '/type/ip/' + ip,
        headers=headers)
    assert r.status_code == 200

def simple_request():
    return requests.get(os.environ['IPREPD_NGINX'])

class TestSuite:
    """ Basic Test Suite to be run on blocking mode iprepd-nginx """

    def test_missing_reputation(self):
        assert is_healthy()
        delete_reputation(get_ip())
        r = simple_request()
        assert r.status_code == 200
        assert r.text == "the backend!\n"

    def test_good_reputation(self):
        time.sleep(7)
        assert is_healthy()
        update_reputation(90, get_ip())
        r = simple_request()
        assert r.status_code == 200
        assert r.text == "the backend!\n"

    def test_bad_reputation(self):
        time.sleep(7)
        assert is_healthy()
        update_reputation(0, get_ip())
        r = simple_request()
        assert r.status_code == 429

        
