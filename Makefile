SHELL := bash
.ONESHELL:
.DELETE_ON_ERROR:

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --warn-undefined-variables

FENNEL ?= fennel
VUSTED ?= vusted

# Note: The --correlate flag is likely to cause conflicts.
FNL_FLAGS ?=
FNL_EXTRA_FLAGS ?=

VUSTED_FLAGS ?= --shuffle --output=utfTerminal
VUSTED_EXTRA_FLAGS ?=

REPO_ROOT:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
TEST_ROOT:=$(REPO_ROOT)/test
SPEC_ROOT:=$(TEST_ROOT)

FNL_SPECS:=$(wildcard $(SPEC_ROOT)/*_spec.fnl)
LUA_SPECS:=$(FNL_SPECS:%.fnl=%.lua)

FNL_SRC_DIR=fnl

FNL_SRC:=$(wildcard $(FNL_SRC_DIR)/*.fnl)
FNL_SRC+=$(wildcard $(FNL_SRC_DIR)/*/*.fnl)
FNL_SRC+=$(wildcard $(FNL_SRC_DIR)/*/*/*.fnl)
FNL_SRC:=$(filter-out %/macros.fnl,$(FNL_SRC))
LUA_RES:=$(FNL_SRC:$(FNL_SRC_DIR)/%.fnl=lua/%.lua)

FNL_SRC_DIRS:=$(wildcard $(FNL_SRC_DIR)/*/*/)

REPO_FNL_DIR := $(REPO_ROOT)/$(FNL_SRC_DIR)
REPO_FNL_PATH := $(REPO_FNL_DIR)/?.fnl;$(REPO_FNL_DIR)/?/init.fnl
REPO_MACRO_DIR := $(REPO_FNL_DIR)
REPO_MACRO_PATH := $(REPO_MACRO_DIR)/?.fnl;$(REPO_MACRO_DIR)/?/init.fnl

.DEFAULT_GOAL := help
.PHONY: help
help: ## Show this help
	@echo 'Targets:'
	@egrep -h '^\S+: .*## \S+' $(MAKEFILE_LIST) | sed 's/: .*##/:/' | column -t -s ':' | sed 's/^/  /'

lua/%.lua: $(FNL_SRC_DIR)/%.fnl
	@mkdir -p $(dir $@)
	@$(FENNEL) \
		$(FNL_FLAGS) \
		$(FNL_EXTRA_FLAGS) \
		--add-macro-path "$(REPO_MACRO_PATH);$(SPEC_ROOT)/?.fnl" \
		--compile $< > $@
	@echo $< "	->	" $@

.PHONY: clean
clean: ## Remove generated files
	@rm -f $(LUA_RES)
	@rm -f $(LUA_SPECS)

.PHONY: build
build: $(LUA_RES)

%_spec.lua: %_spec.fnl
	@$(FENNEL) \
		$(FNL_FLAGS) \
		$(FNL_EXTRA_FLAGS) \
		--correlate \
		--add-macro-path "$(REPO_MACRO_PATH);$(SPEC_ROOT)/?.fnl" \
		--compile $< > $@

.PHONY: test
test: build $(LUA_SPECS) ## Run test
	@$(VUSTED) \
		$(VUSTED_FLAGS) \
		$(VUSTED_EXTRA_FLAGS) \
		$(TEST_ROOT)
