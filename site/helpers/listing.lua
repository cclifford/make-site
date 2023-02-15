#!/usr/bin/env lua

package.path = './site/helpers/lib/?.lua;' .. package.path

json = require "json"
utils = require "utils"
el = require "el"
md = require "md"
argparse = require "arg"

local function make_entries(i,n, doc, tf, s)
   table.sort(i, function (l, r)
				 return tonumber(l.created) > tonumber(r.created)
   end)
   for k, v in ipairs(i) do
	  if k > n and n ~= 0 then break end
	  local link = md.link.new(v.title, v.root_relative_filename)
	  local le = md.list.element.new()
	  doc:append(le)
	  le:append(link)
	  if v.summary ~= nil  and s then
		 le:append(v.summary)
	  end
	  if v.tags ~= nil and tf ~= nil then
		 table:sort(v.tags)
		 local tl = md.list.new()
		 doc:append(tl)
		 for k1, v1 in ipairs(v.tags) do
			local tag = md.link.new(v1, tf .. "#" .. utils.linkify_tag(v1))
			local le = md.list.element.new(tag)
			tl:append(le)
		 end
	  end
   end
end

local function main(a)
   local doc = md.new({title = a["--title"], rss = "false"})
   if a["--subtitle"] ~= nil then
	  doc:append(md.heading.new(a["--subtitle"], 3))
   end
   if a['--comment'] ~= nil then
	  doc:append(a["--comment"])
	  doc:par()
   end
   local list = md.list.new()
   doc:append(list)
   local input
   local n = 0
   if a["-n"] ~= nil then n = tonumber(a["-n"]) end
   if a['-i'] ~= nil then
	  local f = assert(io.open(a['-i'], "r"))
	  input = json.decode(f:read("*all"))
	  f:close()
   else
	  io.stderr:write("Specify an input file (-i)\n")
	  return
   end
   if input == nil then return end
   make_entries(input, n, list, a["--tag-location"], a["-s"])
   if a["-o"] ~= nil then
	  local f = assert(io.open(a["-o"], "w"))
	  f:write(doc:render(1))
   else
	  io.stderr:write("Specify an output file (-o)\n")
   end
end



local arguments = argparse.option.new("-i", true, "pass input JSON file")
arguments:add('-o', true, "output file")
arguments:add('-n', true, "Number of entries")
arguments:add("--title", true, "Title of document")
arguments:add("--subtitle", true, "Subitle of document")
arguments:add("--tag-location", true, "Tag File")
arguments:add("--comment", true, "Optional md-formatted string to show before the tags")
arguments:add("-s", false, "Include summary")
arguments:add("-h", false, "Show Help and quit")


local parser = argparse.new(arguments)
local a = parser:parse(arg)
if a['-h'] then parser:help()
else
   --   print(dump(a))
   main(a)
end
