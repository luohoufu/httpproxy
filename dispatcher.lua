local len = string.len
local upper = string.upper
local sub = string.sub
local print = ngx.print
local exec = ngx.exec

--获取参数的值
local request_method = ngx.var.request_method
if "GET" == request_method then
   args = ngx.req.get_uri_args()
elseif "POST" == request_method then
   ngx.req.read_body()
   args = ngx.req.get_post_args()
else
   return print(Err(err_103))
end

local appkey = args["appkey"]
local version = args["ver"]
local data = args["data"]
local method = args["method"]
local timestamp = args["timestamp"]
local sign = args["sign"]

--不符合参数要求
if appkey == nil or method == nil or version == nil or data == nil or timestamp == nil or sign == nil then
   return print(Err(err_105))
end

--APPKEY不存在
local secret_key = SecretKey(appkey)
if secret_key == nil then
   return print(Err(err_100))
end

--鉴权失败
if secret_key ~= "" then
   local sign_data = appkey..method..version..data..secret_key..timestamp
   local check_sign = ngx.md5(sign_data)
   if check_sign ==nil or upper(check_sign) ~= sign then
      return print(Err(err_101))
   end
end

--请求URL不存在
local dispatch_url = Dispatch(method)
if dispatch_url == nil then
   return print(Err(err_104))
end

--设置请求头和响应头
ngx.req.set_header("Content-Type", "application/x-www-form-urlencoded")
ngx.req.set_header("apiVersion",version)

--设置请求数据
local body = ngx.encode_args({data=data,request_id=RequestId()})
--内部代理跳转
if callback == nil then
   ngx.var.dispatch = dispatch_url
   ngx.req.set_method(ngx.HTTP_POST)
   ngx.req.set_body_data(body)
   return exec("/proxy")
end
