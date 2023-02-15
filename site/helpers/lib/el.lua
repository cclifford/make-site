utils = require "utils"

el = {}

el.attr = {}
el.cdata = {}
el.document = {}
el.box = {}

function el.box:append(v)
   self.children[#self.children+1] = v
   return self
end

function el.box:render(level, pretty)
   pretty = pretty or false
   local children = ""
   for k, v in pairs(self.children) do
	  if type(v) == "string" then children = children .. pad(v, level, pretty) .. "\n" end
	  if type(v) == "table" then
		 children = children .. v:render(level, pretty)
	  end
   end
   return children
end

function el.box.new()
   local ret = {}
   ret.children = {}
   setmetatable(ret, {__index = el.box})
   return ret
end

function el.document:append(c)
   self.children[#self.children+1] = c
   return self
end

function el.document:render_options()
   local opts = ""
   for k, v in pairs(self.options) do
	  opts = opts .. " " .. k .. '="' .. v .. '"'
   end
   return '<?xml version="1.0" encoding="UTF-8"'  .. opts .. ' ?>'
end

function el.document:render(pretty)
   pretty = pretty or false
   children = ""
   for k, v in pairs(self.children) do
	  if type(v) == "string" then children = children .. v .. "" end
	  if type(v) == "table" then
		 children = children .. v:render(0, pretty)
	  end
   end
   return self:render_options() .. children
end

function el.document.new(options)
   local ret = {}
   ret.options = options or {}
   ret.children = {}
   setmetatable(ret, {__index = el.document})
   return ret
end

function el.attr:append(val)
   self[#self+1] = val
   return val
end

function el.cdata:set(value)
   value = value or nil
   if value then 
	  if type(value) ~= "string" then error("CDATA must be provided as a string")
	  else
		 self.value = value
	  end
   end
   return value
end

function el.cdata:render(l, pretty)
   pretty = pretty or false
   local value = self.value:gsub("]]>",  "]]]]><![CDATA[>")
   local text = "<![CDATA["
	  .. value
	  .. "]]>"
   if pretty then text = text .. "\n" end
   return text
end

function el.attr:replace(old, new)
   for k,v in pairs(self) do
	  if v == old then self[k] = new end
   end
end

function el.attr:render()
   return utils.join(self, ' ')
end

function el:append(child)
   if self_close then error("tried to add children to self-closing tag")
   else
	  self.children[#self.children+1] = child
	  return self
   end
end

function el:add_attr(name, value)
   if self.attrs[name] then error("tried to add attribute that already existed")
   else
	  self.attrs[name] = el.attr.new(value)
   end
   return self.attrs[name]
end

function el:add_or_append_attr(name, value)
   if self.attrs[name] ~= nil then self.attrs[name]:append(value)
   else
	  self.attrs[name] = el.attr.new(value)
   end
   return self.attrs[name]
end

function el:render_attributes()
   local attrs = {}
   for k, v in pairs(self.attrs) do
	  attrs[#attrs+1] = k .. '="' .. v:render() .. '"'
   end
   local out = utils.join(attrs, ' ')
   if out ~= "" then out = " " .. out end
   return out
end

local function pad(s, n, pretty)
   if not pretty then return s
   else
	  n = n or 4
	  pad_string = string.rep(" ", n)
	  s = pad_string .. s
	  s = s:gsub("\n", "\n"..pad_string)
	  return s .. "\n"
   end
end

function el:render(level, pretty)
   pretty = pretty or false
   level = level or 0
   local attributes = self:render_attributes()
   local children = ""
   for k, v in pairs(self.children) do
	  if type(v) == "string" then children = children .. pad(v, level+2, pretty) end
	  if type(v) == "table" then
		 children = children .. v:render(level + 2, pretty)
	  end
   end
   if self.self_close then
	  return pad( "<"
		 .. self.name
		 .. attributes
		 .. "/>", level, pretty)
   else
	  return pad("<"
		 .. self.name
		 .. attributes
		 .. ">", level, pretty)
		 .. children
		 .. pad("</"
		 .. self.name
		 .. ">", level, pretty)
   end
end

function el.new(el_name, self_close)
   el_name = el_name or "void"
   self_close = self_close or false
   ret = {}
   ret.name = el_name
   ret.self_close = self_close
   ret.attrs = {}
   ret.children = {}
   setmetatable(ret, {__index = el})
   return ret
end

function el.attr.new(value)
   value = value or nil
   ret = {}
   if type(value) == "string" then
	  ret = utils.split(value, " ")
   elseif type(value) == "table" then
	  for k, v in pairs(value) do
		 ret[#ret+1] = v
	  end
   end
   setmetatable(ret, {__index = el.attr})
   return ret
end

function el.cdata.new(value)
   value = value or nil
   ret = {}
   if value then 
	  if type(value) ~= "string" then error("CDATA must be provided as a string")
	  else
		 ret.value = value
	  end
   end
   setmetatable(ret, {__index = el.cdata})
   return ret
end

return el
