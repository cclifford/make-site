--pandoc.utils = require 'pandoc.utils'

package.path = './site//helpers/lib/?.lua;' .. package.path


utils = require "utils"

return {
   {
	  -- Compiles and writes a data file with document metadata extracted from Pandoc.
	  -- Also, inserts links to the appropriate category on the site tag page.
	  Pandoc = function(p)
		 local data = {}
		 -- Import data from Pandoc variables
		 local data_file = PANDOC_WRITER_OPTIONS.variables["META_WRITE"]
		 local snippet_file = PANDOC_WRITER_OPTIONS.variables["SNIPPET"]
		 local project_root = PANDOC_WRITER_OPTIONS.variables["OUTPUT_ROOT"]
		 local tag_file = PANDOC_WRITER_OPTIONS.variables["TAG_FILE"]
		 local current_file = PANDOC_STATE.input_files[1]
		 -- In the most recent version, Pandoc provides these as internal 'Doc'
		 -- type variables. I wish there were a better way to convert to real Lua
		 -- strings...
		 if data_file ~= nil then data_file = tostring(data_file) end
		 if snippet_file ~= nil then snippet_file = tostring(snippet_file) end
		 if project_root ~= nil then project_root = tostring(project_root) end
		 if tag_file ~= nil then tag_file = tostring(tag_file) end
		 if project_root == nil then return nil end
		 data.updated = io.popen("stat -c %Y " .. current_file):read()
		 data.created = io.popen("stat -c %W " .. current_file):read()
		 data.created_hr = os.date("%Y-%m-%dT%XZ", data.created)
		 data.root_relative_filename = utils.new_root(current_file, project_root)
		 data.relative_filename = current_file
		 data.updated_hr = os.date("%Y-%m-%dT%XZ", data.updated)		 
		 p.meta.created = os.date("%x %X", data.created)
		 p.meta.updated = os.date("%x %X", data.updated)
		 p.meta.author = p.meta.author or p.meta.default_author
		 p.meta.title  = p.meta.title or data.root_relative_filename
		 p.meta.tags = utils.tags(p.meta)

		 data.tags = p.meta.tags

		 if #data.tags >0 and tag_file ~= nil then
			p.meta.tag_links = utils.make_link_to_tag(data.tags, tag_file)
		 end
		 
		 if data_file ~= nil then
			data.rss = p.meta.rss
			data.title = pandoc.utils.stringify(p.meta.title)
			if snippet_file ~= nil and data.rss then
			   local f = assert(io.open(snippet_file, "r"))
			   data.content = f:read("*all")
			   f:close()
			end
			if p.meta.summary ~= nil then data.summary = pandoc.utils.stringify(p.meta.summary) end
			data.meta_date = p.meta.date
			if p.meta.author ~= nil and type(p.meta.author) == "string" then
			   data.author = p.meta.author
			elseif p.meta.author ~= nil then
			   data.author = utils.flatten(p.meta.author)
			end
			data.publish = p.meta.publish
			utils.export_json(data, data_file)
		 end
		 return p
	  end
   },
   {
	  -- Converts inter-document links to properly reflect how the site is laid out
	  Link = function(l)
		 url_components = utils.parse_url(l.target)
		 if not utils.should_be_retargeted(url_components) then
		    return nil
		 end
		 url_components.resource = url_components.resource:gsub("(.+)%." .. url_components.file_extension, "%1.html")
		 return pandoc.Link(
			l.content,
			utils.make_url(url_components),
			l.title, l.attr)
	  end
   }
}
