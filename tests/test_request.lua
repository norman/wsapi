
pcall(require, "luarocks.require")
require "wsapi.request"

local function make_env_get(qs)
   return {
      REQUEST_METHOD = "GET",
      QUERY_STRING = qs or "",
      CONTENT_LENGTH = 0,
      PATH_INFO = "/",
      SCRIPT_NAME = "",
      CONTENT_TYPE = "x-www-form-urlencoded",
      input = {
	 read = function () return nil end
      }
   }
end

local function make_env_post(pd, type, qs)
   pd = pd or ""
   return {
      REQUEST_METHOD = "POST",
      QUERY_STRING = qs or "",
      CONTENT_LENGTH = #pd,
      PATH_INFO = "/",
      CONTENT_TYPE = type or "x-www-form-urlencoded",
      SCRIPT_NAME = "",
      input = {
	 post_data = pd,
	 current = 1,
	 read = function (self, len)
		   if self.current > #self.post_data then return nil end
		   local s = self.post_data:sub(self.current, len)
		   self.current = self.current + len
		   return s
		end
      }
   }
end

local function encode_multipart(boundary, fields)
  local parts = { "--" .. boundary }
  for _, t in ipairs(fields) do
     parts[#parts+1] = '\r\nContent-Disposition: form-data; name="' .. t[1] .. '"\r\n\r\n' .. t[2] .. '\r\n--' .. boundary
  end
  return table.concat(parts)
end

local function is_empty_table(t)
   for k, v in pairs(t) do return false, k, v end
   return true
end

-- Test empty GET
local env = make_env_get()
local req = wsapi.request.new(env)
assert(req.path_info == env.PATH_INFO)
assert(req.method == env.REQUEST_METHOD)
assert(req.script_name == env.SCRIPT_NAME)
assert(req.query_string == env.QUERY_STRING)
assert(is_empty_table(req.GET))
assert(is_empty_table(req.POST))

-- Test one-parameter GET
local env = make_env_get("foo=bar")
local req = wsapi.request.new(env)
assert(req.GET["foo"] == "bar")
assert(req.params["foo"] == "bar")
assert(is_empty_table(req.POST))

-- Test one-parameter POST
local env = make_env_post("foo=bar")
local req = wsapi.request.new(env)
assert(is_empty_table(req.GET))
assert(req.POST["foo"] == "bar")
assert(req.params["foo"] == "bar")

-- Test empty POST that is not form-encoded
local env = make_env_post(nil, "application/json")
local req = wsapi.request.new(env)
assert(is_empty_table(req.GET))
assert(req.POST["post_data"] == "")
assert(req.params["post_data"] == "")

-- Test POST with content that is not form-encoded
local env = make_env_post("{ foo: bar }", "application/json")
local req = wsapi.request.new(env)
assert(is_empty_table(req.GET))
assert(req.POST["post_data"] == "{ foo: bar }")
assert(req.params["post_data"] == "{ foo: bar }")

-- Test two-parameter GET
local env = make_env_get("foo=bar&baz=boo")
local req = wsapi.request.new(env)
assert(req.GET["foo"] == "bar")
assert(req.GET["baz"] == "boo")
assert(req.params["foo"] == "bar")
assert(req.params["baz"] == "boo")
assert(is_empty_table(req.POST))

-- Test two-parameter POST
local env = make_env_post("foo=bar&baz=boo")
local req = wsapi.request.new(env)
assert(is_empty_table(req.GET))
assert(req.POST["foo"] == "bar")
assert(req.POST["baz"] == "boo")
assert(req.params["foo"] == "bar")
assert(req.params["baz"] == "boo")

-- Test POST with GET
local env = make_env_post("baz=boo", nil, "foo=bar")
local req = wsapi.request.new(env)
assert(req.GET["foo"] == "bar")
assert(req.POST["baz"] == "boo")
assert(req.params["foo"] == "bar")
assert(req.params["baz"] == "boo")

-- Test one-parameter POST
local env = make_env_post("foo=bar")
local req = wsapi.request.new(env)
assert(is_empty_table(req.GET))
assert(req.POST["foo"] == "bar")
assert(req.params["foo"] == "bar")

-- Test multipart/form-data
local boundary = "hello"
local env = make_env_post(encode_multipart(boundary, { { "foo", "bar\nbar" }, { "baz", "boo" } }),
					   "multipart/form-data; boundary=" .. boundary)
local req = wsapi.request.new(env)
assert(is_empty_table(req.GET))
assert(req.POST["foo"] == "bar\nbar")
assert(req.POST["baz"] == "boo")
assert(req.params["foo"] == "bar\nbar")
assert(req.params["baz"] == "boo")
