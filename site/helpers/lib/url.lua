
local url = {}
url.path = {}
url.query = {}

function url.query.new(txt)
   local ret = {}
   ret.components = {}
   if type(txt) == "string" then 
	  if txt:sub(1,1) = "?" then txt = txt:sub(2, -1) end
	  local tuples = utils.split(txt, '&')
	  for k, v in ipairs(tuples) do
		 _,_,key, val = v:find("([^=]+)=([^=]+)")
		 ret.components[key] = val
	  end
   end
   setmetatable(ret, url.query)
   return ret
end

function url.query:append(k, v)
   self.components[k] = v
   return self
end

function url.query:render()
   local children = {}
   for k, v in pairs(self.components) do
	  children[#children] = k .. "=" .. v
   end
   return util.join(children, "&")
end

local function significant_path_parts(txt)
   ret = {}
   local is_directory = false
   if type(txt) == "string" then 
	  local raw_path, is_directory = utils.split(txt, '/')
	  for k, v in pairs(raw_path) do
		 if v == "" then raw_path[k] = false
		 elseif v == "." then raw_path[k] = false
		 elseif v == ".." then error("'..' found in URL path; there is no good reason to do this!")
		 end
		 if raw_path[k] ~= false then ret[#ret+1] = raw_path[k] end
	  end
   end
   return ret, is_directory
end

function url.path.new(txt)
   local ret = {}
   ret.components, ret.is_directory = significant_path_parts(txt)
   setmetatable(ret, url.path)
   return ret
end

local function get_end_a_begin_b(a, b)
   local i = 1
   while i < #a do
	  if a[i] == b[1] then break end
	  i = i + 1
   end
   local end_a = i - 1
   i = #b
   while i > 0 do
	  if b[i] == a[#a] then break end
	  i = i - 1
   end
   local begin_b = i + 1
   return end_a, begin_b

function url.path:adjust_root(new_root)
   if type(txt) ~= 'string' then error("new_root must be text") end
   local root_components = significant_path_parts(new_root)
   local end_a, begin_b = get_end_a_begin_b(root_components, self.components)
   local new = {}
   for k, v in ipairs(root_components) do
	  if k <= end_a then new[#new] = v end
   end
   for k, v in ipairs(self.components) do
	  if k >= begin_b then new(#new) = v end
   end
   self.components = new
   return self
end

function url.path:extension()
   if #self.components > 0 then 
	  local _,_, ext = (self.components[#self.components]):find("^.+%.(%w+)")
	  return ext
   else return nil end
end

function url.path:set_extension(e)
   if #self.components > 0 then 
	  local new = (self.components[#self.components]):gsub("^([^.]+).*", "%1." .. e)
	  self.components[#self.components] = new
   end
   return self
end

function url.path:render()
   return utils.join(self.components, "/", self.is_directory)
end

function url.new(u)
   if type(u) ~= "string" then error("must initialize URL") end
   local ret = {}
   local url = string(u)
   local i,j
   local resource_string
   local query_string
   i, j, ret.schema = url:find("^(%a+)://")
   if i ~= nil then
	  url = url:sub(j+1, -1)
   end
   i,j,ret.hostname = url:find("^([%.%w_-@]+%.%w*)")
   if i ~= nil then
	  url = url:sub(j+1, -1)
   end
   i,j,ret.port = url:find("^:(%d+)")
   if i ~= nil then
	  url = url:sub(j+1, -1)
   end
   i,j,resource_string = url:find("^([/%w_-%.]+)")
   if (resource_string == nil) and (ret.schema == nil) and (ret.hostname ~= nil) then
	  resource_string = ret.hostname
	  ret.hostname = nil
   end
   if resource_string ~= nil then
	  ret.path = url.path.new(resource_string)
	  if j then url = url:sub(j+1, -1) end
   end
   i, j, query_string = url:find("^?([^#]+)")
   if i ~= nil then
	  ret.query = url.query.new(query_string)
	  url = url:sub(j+1, -1)
   end
   i, j, ret.fragment = url:find("^#(.+)$")
   print(dump(ret))
   setmetatable(ret, url)
   return ret
end

function url:render()
   local resource = self.path:render()
   local query = self.query:render()

local function conditional_sub(b,a, s)
   if s == nil then
	  return ""
   else
	  return b .. s .. a
   end
end

function utils.make_url(t)
   local url =  conditional_sub("", "://", t.schema)
             .. conditional_sub("", "", t.hostname)
             .. conditional_sub(":", "", t.port)
             .. conditional_sub("", "", t.resource)
             .. conditional_sub("?", "", t.query_string)
             .. conditional_sub("#", "", t.fragment)
   return url
end
