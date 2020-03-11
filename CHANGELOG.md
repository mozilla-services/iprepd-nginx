## Change log

### 0.1.13

* Expect comma delimited strings for `IPREPD_WHITELISTED_LIST` and `AUDIT_URI_LIST` and parse
  them in the module, instead of requiring tables be constructed in the nginx `init_by_lua_block`
