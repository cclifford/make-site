if json == nil then json = require "json" end

local utils = {}


function utils.flatten(tags)
   for k, v in pairs(tags) do
	  tags[k] = pandoc.utils.stringify(v)
   end
   return tags
end


local function md_tags(m)
   local ret_tags = {}
   local ret_meta = {}
   if m.tags ~= nil then ret_tags = utils.flatten(m.tags) end
   return ret_tags, ret_meta
end

local function org_tags(m)
   local ret_meta = {}
   local ret_tags = {}
   if m.keywords ~= nil then 
	  local str = pandoc.utils.stringify(m.keywords)
	  str = str:gsub("\n", ",")
	  str = utils.split(str, ",")
	  for k, v in ipairs(str) do
		 v = v:gsub("^%s+", ""):gsub("%s+$", "")
		 if v:match("=") then
			local _,_,k1, v1 = v:find("([^=]*)=([^=]*)")
			if k1 ~= nil and v1 ~= nil then
			   ret_meta[k1] = v1
			end
		 elseif v ~= "" then
			ret_tags[#ret_tags + 1] = v
		 end
	  end
   end
   return ret_tags, ret_meta
end

function utils.tags(m)
   local tags = {}
   local meta = {}
   repeat
	  tags, meta = md_tags(m)
	  if next(tags) ~= nil then break end
	  tags, meta = org_tags(m)
	  if next(tags) ~= nil then break end
   until true
   if tags ~= nil then
	  m.tags = tags
	  m.keywords = tags
   end
   if meta ~= nil then
	  for k, v in pairs(meta) do
		 m[k] = v
	  end
   end
   return tags
end

function utils.linkify_tag(x)
   return x:gsub("_", "__"):gsub(" ", "_"):gsub("[^%w_-]", ""):sub(1, 15) .. tostring(x:len())
end

function utils.make_link_to_tag(tags, file)
   local ret = {}
   for k, v in ipairs(tags) do
	  local fragment = utils.linkify_tag(pandoc.utils.stringify(v))
	  ret[#ret + 1] = pandoc.Link(v, file .. "#" .. fragment)
   end
   return ret
end

function utils.dir_is_prefix(st, pre)
   local st_ = utils.split(st, "/")
   local pre_ = utils.split(pre, "/")
   local a = true
   for k, v in ipairs(pre_) do
	  a = a and (v == st_[k])
   end
   return a
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function utils.split(s, sep)
   sep = sep or ','
   local matches_end = (s:sub(-1,-1) == sep)
   local ret = {}
   local match = s:find(sep)
   while match ~= nil do
	  if match ~= 0 then
		 ret[#ret+1] = s:sub(1, match-1)
		 s = s:sub(match + 1, -1)
	  end
	  match = s:find(sep)
   end
   if not matches_end then ret[#ret+1] = s end
   return ret, matches_end
end

local function decode_url_fragment(u)
   local url = u:gsub("+", " ")
   url = url:gsub("%%(%x%x)", function (c) return string.char(tonumber(c, 16)) end)
   return url
end

local function decode_parameter_string(u)
   local ret = {}
   for k, v in u:gmatch('([^&=?]-)=([^&=?]+)') do
	  ret[k] = v
   end
   return ret
end

function utils.parse_url(u)
   local url = u
   local ret = {}
   local i,j
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
   i,j,ret.resource = url:find("^([/%w_-%.]+)")
   if ret.resource == nil then
	  ret.resource = ret.hostname
	  ret.hostname = nil
   end
   if ret.resource ~= nil then
	  _,_, ret.file_extension = ret.resource:find("^.+%.(%w+)")
	  ret.path, ret.is_directory = utils.split(ret.resource, '/')
	  if j then url = url:sub(j+1, -1) end
   end
   i, j, ret.parameter_string = url:find("^?([^#]+)")
   if i ~= nil then
	  ret.parameters = decode_parameter_string(ret.parameter_string)
	  url = url:sub(j+1, -1)
   end
   i, j, ret.fragment = url:find("^#(.+)$")
   return ret
end

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
             .. conditional_sub("?", "", t.parameter_string)
             .. conditional_sub("#", "", t.fragment)
   return url
end

function utils.should_be_retargeted(t)
   local to_html_extensions = PANDOC_WRITER_OPTIONS.variables["TO_HTML"]
   if to_html_extensions == nil then
	  return false
   end
   local allowed
   if t.file_extension ~= nil then 
	  allowed = string.find(to_html_extensions, t.file_extension)
   end
   local retarget = (t.schema == nil) and (t.file_extension ~= nil) and (allowed ~= nil)
   return retarget
end

function utils.join(t, sep, add_on_end)
   add_on_end = add_on_end or false
   s = ""
   for k, v in pairs(t) do
	  if v then
		 if s == "" then
			s = v
		 else
			s = s .. sep .. v
		 end
	  end
   end
   if add_on_end then
	  s = s .. sep
   end
   return s
end

local function slice(tbl, first, last, step)
  local sliced = {}
  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end
  return sliced
end

function utils.new_root(path, root)
   local path_elements, is_dir = utils.split(path, '/')
   local root_elements = utils.split(root, '/')
   local len = math.min(#path_elements, #root_elements)
   local i = 1;
   while i <= len do
	  if path_elements[i] ~= root_elements[i] then break end
	  i = i+1
   end
   local step = slice(path_elements, i, #path_elements)
   local new = utils.join(step, '/', is_dir)
--   if new:sub(1,1) ~= '/' then new = '/' .. new end
   return new
end

function utils.export_json(t, f)
   file = io.open(f, 'r')
   local content = {}
   local success = false
   if file ~= nil then
	  local text = file:read("*all")
	  success, content = pcall(json.decode, text)
	  file:close()
   end
   if not success then content = {} end
   content[#content+1] = t
   file = assert(io.open(f, 'w'))
   file:write(json.encode(content))
   file:close()
   return true
end

return utils
