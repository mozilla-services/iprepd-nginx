local cjson = require('cjson')
local http = require('socket.http')
local lrucache = require('resty.lrucache')
local ltn12 = require('ltn12')

function fatal_error(error_msg)
  ngx.log(ngx.ERR, error_msg)
  os.exit(1)
end

function iprep_get(url, api_key, ip)
  local headers = {
    Authorization = 'APIKey ' .. api_key
  }

  local response = {}
  local r, code, resp_headers = http.request {
    method = 'GET',
    url = url .. '/' .. ip,
    headers = headers,
    sink = ltn12.sink.table(response)
  }

  return {
    r = r,
    status_code = code,
    body = table.concat(response),
    headers = resp_headers,
  }
end

local _M = {}

function _M.new(options)
  local iprepd_url = options.url or 'http://localhost:8080/'
  local iprepd_threshold = options.threshold
  if not iprepd_threshold then
    fatal_error('Need to pass in a threshold')
  end
  local iprepd_api_key = options.api_key
  if not iprepd_api_key then
    fatal_error('Need to pass in an api_key')
  end

  http.TIMEOUT = options.timeout or 0.01
  local cache_ttl = options.cache_ttl or 30

  -- allow up to 200 items in the cache
  local cache, err = lrucache.new(200)
  if not cache then
    fatal_error('failed to create the cache: ' .. (err or 'unknown'))
  end

  return {
    url = iprepd_url,
    threshold = iprepd_threshold,
    api_key = iprepd_api_key,
    cache_ttl = cache_ttl,
    cache = cache,
  }
end

function _M.check(self, ip)
  -- Get reputation for ip
  local resp = self.cache:get(ip)
  if not resp then
    resp = iprep_get(self.url, self.api_key, ip)
    if resp.status_code == 'timeout' then
      ngx.log(ngx.ERR, 'timed out getting reputation from iprepd')
    else
      self.cache:set(ngx.var.remote_addr, resp, self.cache_ttl)
    end
  end

  -- If the IP was found
  if resp.status_code == 200 then
    local resp_body = cjson.decode(resp.body)

    -- check reputation against threshold
    if resp_body['reputation'] >= self.threshold then
      -- if above threshold, return 403 and log rejections
      ngx.log(ngx.ERR, ngx.var.remote_addr .. ' rejected with a reputation of ' .. resp_body['reputation'])
      ngx.exit(ngx.HTTP_FORBIDDEN)
    end
  end
end

return _M
