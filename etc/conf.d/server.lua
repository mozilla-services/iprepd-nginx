local ltn12 = require('ltn12')
local http = require('socket.http')

function fatal_error(error_msg)
  ngx.log(ngx.ERR, error_msg)
  os.exit(1)
end

-- iprepd options

local iprepd_url = os.getenv("IPREPD_URL") or "http://localhost:8080"
local iprepd_timeout = tonumber(os.getenv("IPREPD_TIMEOUT")) or 0.01 -- in seconds (default 10ms)
local iprepd_api_key = os.getenv("IPREPD_API_KEY")
if not iprepd_api_key then
  fatal_error("Need to set IPREPD_API_KEY")
end
iprepd_threshold = tonumber(os.getenv("IPREPD_REPUTATION_THRESHOLD"))

http.TIMEOUT = iprepd_timeout

iprep = {}
function iprep.get(ip)
  local headers = {
    Authorization = "APIKey " .. iprepd_api_key
  }

  local response = {}
  local r, code, resp_headers = http.request {
    method = 'GET',
    url = iprepd_url .. '/' .. ip,
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

--
-- Cache config
--

-- TTL in seconds
cache_ttl = os.getenv("IPREPD_CACHE_TTL") or 30

lrucache = require("resty.lrucache")

-- allow up to 200 items in the cache
cache, err = lrucache.new(200)
if not cache then
  fatal_error("failed to create the cache: " .. (err or "unknown"))
end
