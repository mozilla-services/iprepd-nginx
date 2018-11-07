--
-- Forked from https://github.com/lonelyplanet/openresty-statsd
--
local _M = {}

-- this table will be shared per worker process
-- if lua_code_cache is off, it will be cleared every request
_M.buffer = {}

function _M.flush(host, port)
  if pcall(function()
    local udp = ngx.socket.udp()
    udp:setpeername(host, port)
    udp:send(_M.buffer)
    udp:close()
  end) then
    -- pass
  else
    ngx.log(ngx.ERR, "Error sending stats to statsd at " .. host .. ":" .. port)
  end

  for k in pairs(_M.buffer) do
    _M.buffer[k] = nil
  end
end

function _M.register(bucket, suffix)
  table.insert(_M.buffer, bucket .. ':' .. suffix .. '\n')
end

function _M.time(bucket, time)
  _M.register(bucket, time .. '|ms')
end

function _M.set(bucket, value)
  _M.register(bucket, value .. '|s')
end

function _M.count(bucket, n)
  _M.register(bucket, n .. '|c')
end

function _M.incr(bucket)
  _M.count(bucket, 1)
end

return _M
