--
-- Forked from https://github.com/lonelyplanet/openresty-statsd
--
local _M = {}

_M.buffer = {count=0}

function _M.flush(host, port)
  if pcall(function()
    local udp = ngx.socket.udp()
    udp:setpeername(host, port)
    _M.buffer['count'] = nil
    udp:send(_M.buffer)
    udp:close()
  end) then
    -- pass
  else
    ngx.log(ngx.ERR, 'Error sending stats to statsd at ' .. host .. ':' .. port)
  end

  -- reset buffer
  _M.buffer = {count=0}
end

function _M.buffer_count()
  return _M.buffer['count']
end

function _M.register(bucket, suffix)
  _M.buffer['count'] = _M.buffer['count'] + 1
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
