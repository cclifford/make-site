#!/usr/bin/env lua

package.path = './site/helpers/lib/?.lua;' .. package.path

TAG_CHARACTER = "#"

json = require "json"
utils = require "utils"
el = require "el"
md = require "md"
argparse = require "arg"

local function flatten(v)
   if type(v) == "string" then return v
   elseif type(v) == "table" then return utils.join(v, " ")
   else error("bad type") end
end

local function should_include(rss, file, prefix)
   local a = true
   if prefix ~= nil and file ~= nil then
	  a = a and utils.dir_is_prefix(file, prefix)
   end
--   if rss ~= nil then a = a and rss end
   return a
end

local function make_entry(v, data, entries, base)
   --   print(dump(v))
   local entry = el.new("entry", false)
   if v.title ~= nil then
	  local title = el.new("title", false)
	  title:append(flatten(v.title))
	  entry:append(title)
   end
   if v.created ~= nil and v.root_relative_filename ~= nil then
	  local id = el.new("id")
	  id:append(base .. v.root_relative_filename .. "#" .. v.created)
	  entry:append(id)
   end
   if v.updated_hr ~= nil then
	  local updated = el.new("updated")
	  updated:append(v.updated_hr)
	  entry:append(updated)
   end
   if v.author ~= nil then
	  if type(v.author) == "string" then
		 local author = el.new("author")
		 local name = el.new("name")
		 author:append(name:append(v.author))
		 entry:append(author)
		 if data.authors[v.author] == nil then
			data.authors[v.author] = {v}
		 else (data.authors[v.author])[(#data.authors[v.author]) + 1] = v end

	  elseif type(v.author) == "table" then
		 for k, v2 in pairs(v.author) do
			local a = el.new("author")
			local name = el.new("name")
			a:append(name:append(v2))
			entry:append(a)
			if data.authors[v2] == nil then
			   data.authors[v2] = {v}
			else (data.authors[v2])[(#data.authors[v2]) + 1] = v end
		 end
	  end
   end
   if v.content ~= nil then
	  local content = el.new("content")
	  content:add_attr("type", "html")
	  local cdata = el.cdata.new(v.content)
	  content:append(cdata)
	  entry:append(content)
   end
   if v.root_relative_filename ~= nil then
	  local link = el.new("link", true)
	  link:add_or_append_attr("rel", "alternate")
	  link:add_or_append_attr("href", base.. v.root_relative_filename)
	  entry:append(link)
   end
   if v.tags ~= nil and type(v.tags) == "table" then
	  for key, val in pairs(v.tags) do
		 local tag = el.new("category", true)
		 tag:add_attr("term", val)
		 tag:add_attr("label", val)
		 if data.tags[val] == nil then data.tags[val] = {v}
		 else (data.tags[val])[#(data.tags[val]) + 1] = v end
		 entry:append(tag)
	  end
   end
   if v.created_hr ~= nil then
	  local published = el.new("published")
	  published:append(v.created_hr)
	  entry:append(published)
   end
   if v.rss then entries:append(entry) end
end
   
local function fill_header_matter(data, a, doc)
   local id = el.new("id")
   doc:append(id:append(a["--base-url"]))
   local title = el.new("title")
   doc:append(title:append(a["--atom-title"]))
   local updated = el.new("updated")
   doc:append(updated:append(os.date("%Y-%m-%dT%XZ")))
   local link = el.new("link", true)
   link:add_attr("rel", "self")
   link:add_attr("href", a["--base-url"] .. "/" .. a["--atom-feed"])
   doc:append(link)
   link = el.new("link", true)
   link:add_attr("rel", "alternate")
   link:add_attr("href", a["--base-url"])
   doc:append(link)
   if a["--atom-author"] ~= nil then
	  for k, v in pairs(data.authors) do
		 local author = el.new("author")
		 local name = el.new("name")
		 doc:append(author:append(name:append(k)))
	  end
   else
	  local author = el.new("author")
	  local name = el.new("name")
	  doc:append(author:append(name:append(a["--atom-author"])))
   end
   for k, v in pairs(data.tags) do
	  local tag = el.new("category", true)
	  tag:add_attr("term", k)
	  tag:add_attr("label", k)
	  doc:append(tag)
   end
   if a["--atom-icon"] ~= null then
	  local icon = el.new("icon")
	  doc:append(icon:append(a["--atom-icon"]))
   end
   if a["--atom-subtitle"] ~= null then
	  local subtitle = el.new("subtitle")
	  doc:append(subtitle:append(a["--atom-subtitle"]))
   end
end

local function make_md_tag_file(data, doc, base_url, comment)
   local tags = {}
   for k, v in pairs(data.tags) do
	  tags[#tags+1] = k
   end
   table.sort(tags)
   for k, v in pairs(tags) do
	  table.sort(data.tags[v],
				 function(a, b)
					return flatten(a.title) < flatten(b.title)
	  end)
	  local div = el.new("div")
	  local anchor = el.new("a")
	  local fragment = utils.linkify_tag(v)
	  anchor:add_attr("name", fragment)
	  anchor:add_attr("href", "#" .. fragment)
	  anchor:add_attr("class", "link-target")
	  doc:append(div)
	  div:add_attr("class", "flexilist")
	  div:append(md.heading.new(anchor:render() .. v, 3))
	  local l = md.list.new()
	  for k1, v1 in pairs(data.tags[v]) do
		 local text = flatten(v1.title)
		 local url = v1.root_relative_filename
		 local le = md.list.element.new()
		 l:append(le)
		 le:append(md.link.new(text, url))
	  end
	  div:append(l)
	  div:append("\n")
   end
   return doc
end

function main(a)
   local tagfile = md.new({rss = "false", author = a["--atom-author"], title = "All Tags"})
   local doc = el.document.new()
   local feed = el.new("feed")
   feed:add_attr("xmlns", "http://www.w3.org/2005/Atom")
   local tag_author_data = {}
   tag_author_data.authors = {}
   tag_author_data.tags = {}
   local input = ""
   local heading_matter = el.box.new()
   local entries = el.box.new()
   feed:append(heading_matter)
   feed:append(entries)
   doc:append(feed)
   if a['-i'] ~= nil then
	  f = assert(io.open(a['-i'], "r"))
	  input = json.decode(f:read("*all"))
	  f:close()
   else
	  io.stderr:write("Specify an input file (-i)\n")
	  return
   end
   for k, v in pairs(input) do
	  if should_include(v.rss, v.relative_filename, a['--prefix']) then 
		 make_entry(v, tag_author_data, entries, a["--base-url"])
	  end
   end
   fill_header_matter(tag_author_data, a, heading_matter)
   local div = el.new("div")
   if a["--tag-comment"] ~= nil then tagfile:append(a["--tag-comment"]) end
   div:add_attr("class", "flexilist-container")
   tagfile:append(div)
   make_md_tag_file(tag_author_data, div, a["--base-url"], a["--tag-comment"])
   if a["--atom"] ~= nil then
	  local f = assert(io.open(a["--atom"], "w"))
	  f:write(doc:render())
	  f:close()
   else io.stderr:write("specify a file to write atom feed to (--atom)\n") end
   if a["--tags"] ~= nil then
	  local f = assert(io.open(a["--tags"], "w"))
	  f:write(tagfile:render(-3))
	  f:close()
   else io.stderr:write("specify a file to write tags to (--tags)\n") end
   --print(doc:render(true))
   --print(tagfile:render(1))
end

local arguments = argparse.option.new("-i", true, "pass input JSON file")
arguments:add('--atom', true, "RSS output file")
arguments:add('--tags', true, "Tag output file")
arguments:add('--prefix', true, "include only files under this prefix")
arguments:add("--base-url", true, "URL relative to which article items are found")
arguments:add("--atom-link", true, "URL of site main page")
arguments:add("--atom-author", true, "Main author of feed")
arguments:add("--atom-title", true, "Title of feed")
arguments:add("--atom-subtitle", true, "Optional subtitle of feed")
arguments:add("--atom-feed", true, "Feed location relative to base url")
arguments:add("--tag-comment", true, "Optional md-formatted string to show before the tags")
arguments:add("-h", false, "Show Help")


local parser = argparse.new(arguments)
local a = parser:parse(arg)
if a['-h'] then parser:help()
else
   --   print(dump(a))
   main(a)
end
