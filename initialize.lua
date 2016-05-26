local secret = {APP1010TEST="s32k98d5102309"}
local db_config = {host = "127.0.0.1",port = 3306,database = "apidb",user = "readeruser",password = "pxqects123021Nbp"}
local sql_reload = "SELECT method_name,request_api_url FROM api_method"
local sql_prefix = "SELECT request_api_url FROM api_method WHERE method_name = "

err_100 = '{"code":100,"message":"无鉴权用户信息","data":{},"request_id":"%s"}'
err_101 = '{"code":101,"message":"鉴权验证失败","data":{},"request_id":"%s"}'
err_102 = '{"code":102,"message":"鉴权认证失败（参数异常）","data":{},"request_id":"%s"}'
err_103 = '{"code":103,"message":"内部接口调用失败","data":{},"request_id":"%s"}'
err_104 = '{"code":104,"message":"无接口信息","data":{},"request_id":"%s"}'
err_105 = '{"code":105,"message":"缺少关键参数","data":{},"request_id":"%s"}'

global = ngx.shared.global

local ffi = require("ffi")
ffi.cdef[[
struct timeval {
  long int tv_sec;
  long int tv_usec;
};
int gettimeofday(struct timeval *tv, void *tz);
]]

--获取时间　年月日时分秒毫秒
local tm = ffi.new("struct timeval")
function RequestId()
  ffi.C.gettimeofday(tm,nil)
  local sec =  tonumber(tm.tv_sec)
  local usec =  tonumber(tm.tv_usec)
  return os.date("%Y%m%d%H%M")..sec..usec
end

--输出错误信息
function Err(err_code)
  return string.format(err_code,RequestId())
end

--获取secret_key
function SecretKey(key)
  return secret[key]
end

--获取代理的地址
function Dispatch(key)
  local value = global:get(key)
  if value ~= nil then
    return value
  end
  return FromDatabase(key)
end

--数据不存在时，从mysql中查询
function FromDatabase(key)
  local mysql = require "resty.mysql"
  local db,err = mysql:new()
  if not db then
    ngx.log(ngx.ERR,"failed to instantiate mysql: "..err)
    return nil
  end

  db:set_timeout(1000)
  local ok, err, errno, sqlstate = db:connect(db_config)
  if not ok then
    ngx.log(ngx.ERR,"failed to connect: "..err..": ", errno.." "..sqlstate)
    return nil
  end

  local res, err, errno, sqlstate = db:query(sql_prefix..ngx.quote_sql_str(key),1)
  if not res then
    ngx.log(ngx.ERR,"bad result: "..err..": "..errno..": "..sqlstate..".")
    return nil
  end

  if res ~= nil and res[1] ~= nil then
    local value = res[1].request_api_url
    global:set(key, value)
    return value
  end
  return nil
end


--数据重新加载
function DispatchReload()
   local mysql = require "resty.mysql"
   local db,err = mysql:new()
   if not db then
      ngx.log(ngx.ERR,"failed to instantiate mysql: "..err)
      return nil
   end

   db:set_timeout(1000)
   local ok, err, errno, sqlstate = db:connect(db_config)
   if not ok then
      ngx.log(ngx.ERR,"failed to connect: "..err..": ", errno.." "..sqlstate)
      return nil
   end

   local res, err, errno, sqlstate = db:query(sql_reload)
   if not res then
      ngx.log(ngx.ERR,"bad result: "..err..": "..errno..": "..sqlstate..".")
      return nil
   end

   for k,v in pairs(res) do
      local key = v.method_name
      local value = v.request_api_url
      local exist_value = global:get(key)
      if exist_value ~= nil then
         global:replace(key, value)
      else
         global:set(key, value)
      end
   end
   ngx.log(ngx.ERR,'数据重新加载成功。')
end
