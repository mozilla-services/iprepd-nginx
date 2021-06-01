## Change log

### 0.1.14
* `IPREPD_WHITELISTED_LIST` has been deprecated and `IPREPD_ALLOWLIST` has been added. If both are specified `IPREPD_ALLOWLIST` takes precedence. `IPREPD_WHITELISTED_LIST` will be removed in a future release.
* Build and test process has changed resulting in leaner docker image for production deployments
* The allowlist functionality now supports ipv6. This was done by changing a dependency from iputils to libcidr-ffi. This requires libcidr to be installed.
* Uses newer iprepd api version
### 0.1.13

* Expect comma delimited strings for `IPREPD_WHITELISTED_LIST` and `AUDIT_URI_LIST` and parse
  them in the module, instead of requiring tables be constructed in the nginx `init_by_lua_block`
