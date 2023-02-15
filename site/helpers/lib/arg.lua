
argparse = {}
argparse.option = {}
argparse.result = {}

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


function argparse.option:add(flag, t, desc)
   self[flag] = {argument = t, description = desc}
   return self
end

function argparse.option:merge(a)
   for k, v in pairs(a) do
	  self[k] = v
   end
   return self
end

function argparse:add(o)
   self.options:merge(o)
   return self
end

function argparse:flag_type(word)
   local ret = 0
   for k, v in pairs(self.options) do
	  if k == word then
		 ret = ret + 2
		 if v.argument then ret = ret + 1
			break
		 end
	  end
   end
   return ret
end

function argparse:help()
   for k, v in pairs(self.options) do
	  print(" " .. k .. "\t" .. v.description)
   end
end

function argparse.option.new(flag, t, desc)
   local ret = {}
   if flag ~= nil then ret[flag] = {argument = t, description = desc} end
   setmetatable(ret, {__index = argparse.option})
   return ret
end

function argparse.option.from_table(t)
   local ret = {}
   for k, v in pairs(t) do
	  ret[k] = v
   end
   setmetatable(ret, {__index = argparse.option})
   return ret
end

function argparse:parse(t)
   local ret = {}
   ret.tail_arguments = {}
   local flag_type = 0
   local skip = false
   local cur = false
   for k, v in pairs(t) do
	  if k == 0 then ret.program_name = v
	  elseif v == "" then
	  elseif v == "lua" then 
	  else
		 if not skip then flag_type = flag_type + self:flag_type(v) % 4 end
		 if flag_type == 0 then
--			skip = true
			ret.tail_arguments[#ret.tail_arguments + 1] = v
		 elseif flag_type == 1 then
			if cur ~= false then ret[cur] = v
			else error("argparse, but cur is unset") end
			cur = false
			flag_type = 0
			skip = false
		 elseif flag_type == 2 then
			ret[v] = true
			flag_type = 0
		 elseif flag_type == 3 then
			flag_type = flag_type - 2
			cur = v
			skip = true
		 end
	  end
   end
   setmetatable(ret, {__index = argparse.result})
   return ret
end

function argparse.new(options)
   local ret = {}
   if options ~= nil then
	  ret.options = options
   else
	  ret.options = argparse.option.new()
   end
   setmetatable(ret, {__index = argparse})
   return ret
end

return argparse

