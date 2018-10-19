local cjson = require('cjson')

-- Get reputation for $remote_addr
local resp = cache:get(ngx.var.remote_addr)
if not resp then
  resp = iprep.get(ngx.var.remote_addr)
  if resp.status_code == "timeout" then
    ngx.log(ngx.ERR, "timed out getting reputation from iprepd")
  else
    cache:set(ngx.var.remote_addr, resp, cache_ttl)
  end
end

-- If the IP was found
if resp.status_code == 200 then
  local resp_body = cjson.decode(resp.body)

  -- check reputation against threshold
  if resp_body["reputation"] >= threshold then
    -- if above threshold, return 403 and log rejections
    ngx.log(ngx.ERR, ngx.var.remote_addr .. " rejected with a reputation of " .. resp_body["reputation"])
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end
end
