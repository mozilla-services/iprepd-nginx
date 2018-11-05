local cjson = require('cjson')
local lrucache = require('resty.lrucache')
local http = require('resty.http')

function fatal_error(error_msg)
  ngx.log(ngx.ERR, error_msg)
  os.exit(1)
end

local _M = {}
local mt = { __index = _M }

function _M.new(options)
  local iprepd_url = options.url or 'http://localhost:8080'

  if iprepd_url:sub(-1) == '/' then
    iprepd_url = iprepd_url:sub(1, -2)
  end

  local cache_ttl = options.cache_ttl or 30

  local iprepd_threshold = options.threshold or fatal_error('Need to pass in a threshold')
  local iprepd_api_key = options.api_key or fatal_error('Need to pass in an api_key')

  -- TODO: Make configurable?
  local cache, err = lrucache.new(200)
  if not cache then
    fatal_error('failed to create the cache: ' .. (err or 'unknown'))
  end

  local self = {
    url = iprepd_url,
    threshold = iprepd_threshold,
    api_key_hdr = {
      ['Authorization'] = 'APIKey ' .. iprepd_api_key,
    },
    cache_ttl = cache_ttl,
    timeout = options.timeout or 10,
    cache = cache,
    cache_errors = options.cache_errors or 0,
  }
  return setmetatable(self, mt)
end

function _M.check(self, ip)
  local httpc = http.new()
  -- set timeout in ms
  httpc:set_timeout(self.timeout)

  -- Get reputation for ip
  local reputation = self.cache:get(ip)
  if not reputation then
    local resp, err = httpc:request_uri(self.url .. '/' .. ip, {
      method  = "GET",
      headers = self.api_key_hdr,
    })
    if err then
      ngx.log(ngx.ERR, 'Error with request to iprepd: ' .. err)
      return
    end

    -- If the IP was found
    if resp.status == 200 then
      reputation = cjson.decode(resp.body)['reputation']
      if reputation and reputation >= 0 and reputation <= 100 then
        self.cache:set(ip, reputation, self.cache_ttl)
      else
        ngx.log(ngx.ERR, 'Unable to parse `reputation` value from response body')
      end
    elseif resp.status == 404 then
      self.cache:set(ip, 100, self.cache_ttl)
    else
      ngx.log(ngx.ERR, 'iprepd responded with a ' .. resp.status .. ' http status code')
      if self.cache_errors == 1 then
        ngx.log(ngx.ERR, 'cache_errors is enabled, setting reputation of ' .. ip .. ' to 100 within the cache')
        self.cache:set(ip, 100, self.cache_ttl)
      end
    end
  end

  -- check reputation against threshold
  if reputation and reputation <= self.threshold then
    -- return 403 and log rejections
    ngx.log(ngx.ERR, ip .. ' rejected with a reputation of ' .. reputation)
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end
end

return _M
