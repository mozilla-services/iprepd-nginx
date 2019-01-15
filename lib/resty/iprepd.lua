local cjson = require('cjson')
local http = require('resty.http')
local iputils = require('resty.iputils')
local lrucache = require('resty.lrucache')
local statsd = require('resty.statsd')

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

  local cache_buffer_count = options.cache_buffer_count or 200

  local iprepd_threshold = options.threshold or fatal_error('Need to pass in a threshold')
  local iprepd_api_key = options.api_key or fatal_error('Need to pass in an api_key')

  local cache, err = lrucache.new(cache_buffer_count)
  if not cache then
    fatal_error(string.format('failed to create the cache: %s', (err or 'unknown')))
  end

  local statsd_client = nil
  if options.statsd_host then
    statsd_client = statsd
  end

  local whitelist = nil
  local whitelist_list = options.whitelist or nil
  if whitelist_list then
    whitelist = iputils.parse_cidrs(whitelist_list)
  end

  local self = {
    url = iprepd_url,
    timeout = options.timeout or 10,
    threshold = iprepd_threshold,
    api_key_hdr = {
      ['Authorization'] = string.format('APIKey %s', iprepd_api_key),
    },
    cache = cache,
    cache_ttl = options.cache_ttl or 30,
    cache_errors = options.cache_errors or 0,
    statsd = statsd_client,
    statsd_host = options.statsd_host,
    statsd_port = options.statsd_port or 8125,
    statsd_max_buffer_count =  options.statsd_max_buffer_count or 100,
    statsd_flush_timer = options.statsd_flush_timer or 5,
    blocking_mode = options.blocking_mode or 0,
    verbose = options.verbose or 0,
    whitelist = whitelist,
  }

  return setmetatable(self, mt)
end

function _M.check(self, ip)
  self:debug_log(string.format("Checking %s", ip))
  ngx.req.set_header('X-Foxsec-IP-Reputation-Below-Threshold', 'false')
  ngx.req.set_header('X-Foxsec-Block', 'false')
  if self.whitelist then
    if iputils.ip_in_cidrs(ip, self.whitelist) then
      self:debug_log(string.format("%s in whitelist", ip))
      return
    end
  end


  local reputation = self:get_reputation(ip)
  if reputation then
    self:debug_log(string.format("Got reputation of %d for %s", reputation, ip))
    ngx.req.set_header('X-Foxsec-IP-Reputation', tostring(reputation))
    if reputation <= self.threshold then
      ngx.req.set_header('X-Foxsec-IP-Reputation-Below-Threshold', 'true')
      ngx.req.set_header('X-Foxsec-Block', 'true')
      if self.statsd then
        self.statsd.incr("iprepd.status.below_threshold")
      end

      if self.blocking_mode == 0 then
        ngx.log(ngx.ERR, string.format("%s is below threshold with a reputation of %d", ip, reputation))
      else
        ngx.log(ngx.ERR, string.format("%s rejected with a reputation of %d", ip, reputation))
        if self.statsd then
          self.statsd.incr("iprepd.status.rejected")
        end
        ngx.exit(ngx.HTTP_FORBIDDEN)
      end
    end
  end

  self:debug_log(string.format("%s accepted", ip))
  if self.statsd then
    self.statsd.incr("iprepd.status.accepted")
  end
end

function _M.get_reputation(self, ip)
  local reputation = self.cache:get(ip)

  if not reputation then
    local httpc = http.new()
    httpc:set_timeout(self.timeout)
    local resp, err = httpc:request_uri(string.format("%s/%s", self.url, ip), {
      method  = "GET",
      headers = self.api_key_hdr,
    })
    self.statsd.incr("iprepd.get_reputation")
    if err then
      if self.statsd then
        self.statsd.incr("iprepd.err." .. err)
      end
      ngx.log(ngx.ERR, string.format("Error with request to iprepd: %s", err))
      return nil
    end

    -- If the IP was found
    if resp.status == 200 then
      reputation = cjson.decode(resp.body)['reputation']
      if not reputation then
        ngx.log(ngx.ERR, 'Unable to parse `reputation` value from response body')
      end
    elseif resp.status == 404 then
      reputation = 100
    else
      ngx.log(ngx.ERR, string.format("iprepd responded with a %d http status code", resp.status))
      if self.statsd then
        self.statsd.incr("iprepd.err." .. resp.status)
      end
      if self.cache_errors == 1 then
        reputation = 100
        self:debug_log(string.format("cache_errors is enabled, setting reputation of %s to 100 within the cache", ip))
      end
    end
  end

  if reputation and reputation >= 0 and reputation <= 100 then
    self.cache:set(ip, reputation, self.cache_ttl)
  end

  return reputation
end

function _M.flush_stats(self)
  if self.statsd then
    if self.statsd.buffer_count() >= self.statsd_max_buffer_count then
      self.statsd.flush(self.statsd_host, self.statsd_port)
    end
  end
end

function _M.async_flush_stats(premature, self)
  self.statsd.flush(self.statsd_host, self.statsd_port)
end

function _M.config_flush_timer(self)
  ngx.timer.every(self.statsd_flush_timer, self.async_flush_stats, self)
end

function _M.debug_log(self, msg)
  if self.verbose == 1 then
    ngx.log(ngx.ERR, string.format("[verbose] %s", msg))
  end
end

return _M
