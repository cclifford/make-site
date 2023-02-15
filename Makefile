#Main Settings
BASE_URL := cclifford.net
SCHEMA := https://
DEFAULT_PATH := 
SITE_TITLE := cclifford
SITE_AUTHOR := Christian Clifford
SITE_SUBTITLE := net
FEED := feed.atom
MAP := site.md
TAGS := tags.md
SITE_FEATURES := $(FEED) $(MAP) $(TAGS)
TO_HTML_EXTENSIONS := md org

#Directories
CONTENT := content
BUILD := site/build
OUTPUT := out
TEMPLATES := site
HELPERS := site/helpers

SITE_AUX_IN :=  $(addprefix $(CONTENT)/, $(SITE_FEATURES))
SITE_AUX_OUT := $(addprefix $(OUTPUT)/, $(SITE_FEATURES:.md=.html))
ATOM_GEN := $(HELPERS)/atom.lua
LISTING_GEN := $(HELPERS)/listing.lua
PANDOC_LUA_FILTERS := $(HELPERS)/lib/filters.lua
PANDOC_HTML5_TEMPLATE := $(TEMPLATES)/pandoc.html5
# You must also provide rules to make these files, if you want them to be actually processed.
STYLESHEETS := /css/normalize.css  /css/fonts.css /style.css
RECENT_LISTING = $(BUILD)/recent.md
TAG_LISTING := $(CONTENT)/$(basename $(TAGS)).md
SITE_LISTING := $(CONTENT)/$(basename $(MAP)).md
ATOM_FILE := $(OUTPUT)/$(basename $(FEED)).atom
SITE_DATA := $(BUILD)/site.json
N_RECENT := 20

HTML_HEADER_BLOCKS := $(BUILD)/recent.html $(BUILD)/site-links.html
HTML_FOOTER_BLOCKS := 
HTML_GENERATION_DEPENDS := $(HTML_HEADER_BLOCKS) $(HTML_FOOTER_BLOCKS)

NOSTANDALONE_PANDOC_FLAGS := $(addprefix --lua-filter=,$(PANDOC_LUA_FILTERS))
NOSTANDALONE_PANDOC_FLAGS += -V TO_HTML="$(TO_HTML_EXTENSIONS)" 
NOSTANDALONE_PANDOC_FLAGS += -M site-title="$(SITE_TITLE)"
NOSTANDALONE_PANDOC_FLAGS += -M site-subtitle="$(SITE_SUBTITLE)"
NOSTANDALONE_PANDOC_FLAGS += -M feed="/$(FEED)"
NOSTANDALONE_PANDOC_FLAGS += -M site-url="$(BASE_URL)"
NOSTANDALONE_PANDOC_FLAGS += -M default_author="$(SITE_AUTHOR)"
NOSTANDALONE_PANDOC_FLAGS += -V OUTPUT_ROOT="$(CONTENT)"
NOSTANDALONE_PANDOC_FLAGS += -t html5
PANDOC_FLAGS += --standalone
PANDOC_FLAGS := --quiet
PANDOC_FLAGS += $(addprefix --css=,$(STYLESHEETS))
PANDOC_FLAGS += $(addprefix --include-before-body=, $(HTML_HEADER_BLOCKS))
PANDOC_FLAGS += $(addprefix --include-after-body=, $(HTML_FOOTER_BLOCKS))
PANDOC_FLAGS += --template $(PANDOC_HTML5_TEMPLATE)
PANDOC_FLAGS += -V TAG_FILE=/$(TAGS)
PANDOC_FLAGS += $(NOSTANDALONE_PANDOC_FLAGS)

PANDOC := /usr/bin/pandoc

DIRECTORIES := $(shell find $(CONTENT) -mindepth 1 -type d | sort -r)

#list of files from most to least recently created.
INPUT_FILES := $(shell find $(CONTENT) -mindepth 1 ! -type d -exec stat -c '%w@%n' {} \+ | sort -r | cut -d '@' -f 2-)
INPUT_FILES := $(filter-out $(TAG_LISTING) $(SITE_LISTING), $(INPUT_FILES))
INPUT_TO_HTML_FILES := $(filter $(addprefix %.,$(TO_HTML_EXTENSIONS)),$(INPUT_FILES))
INPUT_JSON := $(addsuffix .json, $(basename $(INPUT_TO_HTML_FILES)))
INPUT_HTML := $(INPUT_JSON:.json=.html)
INPUT_COPY := $(filter-out $(addprefix %.,$(TO_HTML_EXTENSIONS)),$(INPUT_FILES))

OUTPUT_HTML := $(patsubst $(CONTENT)%,$(OUTPUT)%, $(addsuffix .html,$(basename $(INPUT_TO_HTML_FILES))))
OUTPUT_COPY := $(patsubst $(CONTENT)%,$(OUTPUT)%,$(INPUT_COPY))

.PHONY: all clean recent map publish datafile
.INTERMEDIATE: $(RSS_HTML_SNIPPETS) $(INPUT_JSON) $(INPUT_HTML) $(RECENT_LISTING)
.SECONDARY: $(SITE_DATA)

all: $(OUTPUT_HTML) $(OUTPUT_COPY) $(SITE_AUX_OUT)

clean:
	@rm -rf $(OUTPUT_HTML) $(OUTPUT_COPY) $(SITE_AUX_OUT) $(BUILD)/*
	@find $(OUTPUT) -depth -mindepth 1 -type d -empty -delete
	@echo "done"

define PANDOC_RECIPE

%.json: %.$(1)
	@$$(PANDOC) $$(NOSTANDALONE_PANDOC_FLAGS) -V META_WRITE=$$*_.json -o $$*.snip $$<
	@jq --rawfile html $$*.snip '.[0].content = $$$$html' $$*_.json > $$*.json
	@rm $$*_.json $$*.snip
	@echo " JSON  " $$@

%.html: %.$(1) $$(HTML_GENERATION_DEPENDS)
	@$$(PANDOC) $$(PANDOC_FLAGS) -V timestamp=$$(shell stat -c %W $$<) -o $$*.html $$<
	@echo ' HTML  ' $$@
endef

$(foreach x, $(TO_HTML_EXTENSIONS), $(eval $(call PANDOC_RECIPE,$x)))

$(SITE_DATA): $(INPUT_JSON)
	@touch $(SITE_DATA)
	@cat $(SITE_DATA) $? | jq -s "add | sort_by(.updated)| reverse | unique_by(.root_relative_filename)" > $@
	@echo " JSON  " $@


%/$(FEED) %/$(TAGS) &: $(SITE_DATA)
	@$(ATOM_GEN) -i $^ \
	--atom $*/$(FEED) \
	--tags $*/$(TAGS) \
	--atom-title "$(SITE_TITLE)" \
	--atom-feed $(notdir $(FEED)) \
	--base-url $(SCHEMA)$(BASE_URL)	\
	--atom-author "$(SITE_AUTHOR)"
	@echo ' ATOM  ' $@

$(RECENT_LISTING): $(SITE_DATA)
	@$(LISTING_GEN) -i $(SITE_DATA) -n 5 --subtitle "Recent" -o $@
	@echo ' LIGEN ' $@

%/$(MAP): $(SITE_DATA)
	@$(LISTING_GEN) -i $(SITE_DATA) --tag-location $(TAGS) -s --title "Site Map" -o $@
	@echo ' LIGEN ' $@

#$(OUTPUT)/%.html: $(BUILD)/%.md $(HTML_GENERATION_DEPENDS)
#	@$(MD) $(MDFLAGS) -V timestamp=$(shell stat -c '%W' $<) -o $@ $<
#	@echo ' MD     '$@ 

$(BUILD)/%.html: $(BUILD)/%.md
	@$(PANDOC) $(NOSTANDALONE_PANDOC_FLAGS) -o $@ $<
	@echo ' MD     '$@ 

$(BUILD)/%.html: $(TEMPLATES)/%.md
	@$(PANDOC) $(NOSTANDALONE_PANDOC_FLAGS) -o $@ $<
	@echo ' MD     '$@ 

$(OUTPUT)/%: $(CONTENT)/%
	@mkdir -p $(dir $@)
	@cp -f $< $@
	@echo ' CP     '$@
