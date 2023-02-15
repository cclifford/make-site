utils = require "utils"

md = {}

md.heading = {}
md.link = {}
md.list = {}
md.list.element = {}
md.list.li = {}

function md.heading:render()
   local pound_signs = string.rep("#", self.depth)
   return "\n\n" .. pound_signs.. " " .. self.text .. "\n\n"
end

function md.heading.new(text, l)
   if type(text) ~= "string" then error("Heading can contain only strings") end
   local ret = {}
   l = l or 1
   ret.mdtype = "heading"
   ret.depth = l
   ret.text = text
   setmetatable(ret, {__index = md.heading})
   return ret
end

local function digits(n)
   n = n or 1
   if n < 10 then return 1
   else return 1 + digits(n / 10) end
end

local function pad(s, n, spare)
   spare = spare or 0
   n = n or 4
   local pad_string = string.rep(" ", n)
   local other = string.rep(" ", n + spare)
   s = pad_string .. s
   s = s:gsub("\n", "\n".. other)
   return s
end

function md.list.element:render(level)
   local children = {}
   for k, v in ipairs(self.children) do
	  if type(v) == "string" then children[#children+1] = v
	  else children[#children+1] = v:render(level) end
   end
   return utils.join(children, " ")
end

function md.list.element:append(v)
   self.children[#self.children + 1] = v
   return self
end

function md.list.element.new(c)
   local ret = {}
   if c == nil then ret.children = {}
   elseif type(c) == "table" and c.mdtype == nil then ret.children = c
   elseif type(c) == "table" or type(c) == "string" then ret.children = {c}
   else ret.children = {} end
   ret.mdtype = "element"
   setmetatable(ret, {__index = md.list.element})
   return ret
end

function md.link:render()
   return "[" .. self.alt .. "](" .. self.link .. ")"
end

function md.link.new(alt, link)
   local ret = {}
   ret.alt = alt
   ret.link = link
   ret.mdtype = "link"
   setmetatable(ret, {__index = md.link})
   return ret
end

function md.list:append(v)
   if not (type(v) == "table" and (v.mdtype == "list" or v.mdtype == "element"))
   then error("unsupported list element") end
   self.children[#self.children + 1] = v
   return self
end

function md.list:render(level)
   level = level or 0
   local idx = 0
   local function p()
	  if self.ordered then
		 idx = idx + 1
		 return tostring(idx) .. "."
	  else
		 idx = 1
		 return "-"
	  end
   end
   local padding = 0
   if self.ordered then
	  padding = digits(#self.children) + 1
   else
	  padding = 2
   end
   local children = ""
   for k, v in ipairs(self.children) do
	  if v.mdtype == "element" then
		 children = children .. pad(p() .. pad(v:render(level), padding - digits(i), digits(i)+1), level) .. "\n"
	  end
	  if v.mdtype == "list" then
		 children = children .. v:render(level + 2)
	  end
   end
   return children
end

function md.list.new(c, ordered)
   ordered = ordered or false
   local ret = {}
   if c == nil then ret.children = {}
   elseif (type(c) == "table" and c.mdtype == nil) then ret.children = c
   elseif type(c) == "table" then ret.children = {c}
   else ret.children = {} end
   ret.ordered = ordered
   ret.mdtype = "list"
   setmetatable(ret, {__index = md.list})
   return ret
end

function md:render_metadata()
   if self.meta ~= nil and next(self.meta) ~= nil then 
	  children = ""
	  for k, v in pairs(self.meta) do
		 children = children .. k .. ": " .. v .. "\n"
	  end
	  return "---\n" .. children .. "---\n\n"
   else return "" end
end

function md:render(l)
   l = l or 0
   children = self:render_metadata()
   for k, v in pairs(self.children) do
	  if type(v) == "string" then children = children .. v .. "\n"
	  elseif type(v) == "number" then children = children .. string.rep("\n", l)
	  else children = children .. v:render(l) end
   end
   return children
end

function md:append(v)
   self.children[#self.children+1] = v
   return self
end

function md:par(i)
   i = i or 1
   self.children[#self.children+1] = i
   return self
end

function md.new(m)
   ret = {}
   if m ~= nil then ret.meta = m
   else ret.meta = {} end
   ret.children = {}
   setmetatable(ret, {__index = md})
   return ret
end

return md
