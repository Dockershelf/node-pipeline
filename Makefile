# Dockershelf Node packaging pipeline (Debian-native)
#
# Run from node-pipeline/ inside the deadsnakes-pipeline workspace.
# Sibling node* repos live in the parent directory (..).
#
# Quick start:
#   cp config.env.example config.env
#   make bootstrap
#   make build-builder-images
#   make materialize NODE=22 DIST=trixie
#   make build NODE=22
#   make publish DIST=trixie

SHELL := bash -euo pipefail
PIPELINE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WORKSPACE := $(abspath $(PIPELINE)/..)
DIST_DIR := $(PIPELINE)/dist

ifneq (,$(wildcard $(PIPELINE)/config.env))
include $(PIPELINE)/config.env
endif
export DOCKERSHELF_BUILDER_IMAGE ?= dockershelf-builder
export DOCKERSHELF_TOOLS_IMAGE ?= dockershelf-builder/tools
ifdef DEBFULLNAME
export DEBFULLNAME
endif
ifdef DEBEMAIL
export DEBEMAIL
endif
export DOCKERSHELF_SUITES ?= trixie unstable
export DOCKERSHELF_REFERENCE_NODE ?= 22
export DOCKERSHELF_DEPLOY_HOST ?= apt.dockershelf.example
export DOCKERSHELF_DEPLOY_USER ?= deploy
export DOCKERSHELF_DEPLOY_DIR ?= /var/www/debian
export DOCKERSHELF_DEPLOY_INCOMING ?= /var/www/debian/incoming
export DOCKERSHELF_APT_URL ?= https://apt.dockershelf.example/debian
export DOCKERSHELF_GITHUB_ORG ?= Dockershelf

NODE_VERSIONS := 16 18 20 22 24

.PHONY: all bootstrap clone-node-repos build-tools-image generate-dockerfiles build-builder-images \
	materialize build publish list-dists help

all: help

help:
	@echo "Targets:"
	@echo "  bootstrap                 Clone or seed node* repos into workspace parent"
	@echo "  build-tools-image         Build dockershelf-builder/tools (gbp, dch, …)"
	@echo "  generate-dockerfiles      Generate Dockerfile.{suite} from debian/control"
	@echo "  build-builder-images      Build dockershelf-builder/* (Debian base)"
	@echo "  materialize NODE=22 DIST=trixie"
	@echo "  build NODE=22             Build binary .deb packages (unsigned)"
	@echo "  publish DIST=trixie       Rsync dist/*.deb to DO droplet + reprepro import"
	@echo "  list-dists                Show Debian suites per node repo"
	@echo ""
	@echo "Config: copy config.env.example to config.env"

bootstrap: clone-node-repos
	@echo "Bootstrap complete."

clone-node-repos:
	@for v in $(NODE_VERSIONS); do \
		target="$(WORKSPACE)/node$$v"; \
		if [ -d "$$target/.git" ]; then \
			echo "node$$v already present"; \
		elif git clone --depth 1 "https://github.com/$(DOCKERSHELF_GITHUB_ORG)/node$$v.git" "$$target" 2>/dev/null; then \
			echo "Cloned node$$v from GitHub"; \
		else \
			echo "Seeding node$$v from template..."; \
			"$(PIPELINE)/scripts/seed-node-repo.sh" "$$v" "$$target"; \
		fi; \
	done

build-tools-image:
	@echo "Building $(DOCKERSHELF_TOOLS_IMAGE)"
	@docker build -t "$(DOCKERSHELF_TOOLS_IMAGE)" \
		-f "$(PIPELINE)/dockerfiles/Dockerfile.tools" "$(PIPELINE)/dockerfiles"

generate-dockerfiles: bootstrap
	@mkdir -p "$(PIPELINE)/dockerfiles"
	@REF="$(WORKSPACE)/node$(DOCKERSHELF_REFERENCE_NODE)/debiandirs"; \
	for suite in $(DOCKERSHELF_SUITES); do \
		control="$$REF/$$suite/control"; \
		if [ ! -f "$$control" ]; then \
			echo "ERROR: missing $$control"; \
			exit 1; \
		fi; \
		echo "Generating Dockerfile.$$suite"; \
		"$(PIPELINE)/make-new-image" --codename "$$suite" "$$control" \
			> "$(PIPELINE)/dockerfiles/Dockerfile.$$suite"; \
	done

build-builder-images: generate-dockerfiles build-tools-image
	@for suite in $(DOCKERSHELF_SUITES); do \
		df="$(PIPELINE)/dockerfiles/Dockerfile.$$suite"; \
		if [ ! -f "$$df" ]; then \
			echo "ERROR: missing $$df (run make generate-dockerfiles)"; \
			exit 1; \
		fi; \
		echo "Building $(DOCKERSHELF_BUILDER_IMAGE)/$$suite"; \
		docker build -t "$(DOCKERSHELF_BUILDER_IMAGE)/$$suite" -f "$$df" "$(PIPELINE)/dockerfiles"; \
	done

list-dists:
	@for v in $(NODE_VERSIONS); do \
		if [ -d "$(WORKSPACE)/node$$v/changelogs/mainline" ]; then \
			suites=""; \
			for s in $(DOCKERSHELF_SUITES); do \
				if [ -f "$(WORKSPACE)/node$$v/changelogs/mainline/$$s" ]; then \
					suites="$$suites $$s"; \
				fi; \
			done; \
			echo "node$$v:$$suites"; \
		fi; \
	done

materialize: bootstrap build-tools-image
	@test -n "$(NODE)" || (echo "NODE required, e.g. make materialize NODE=22 DIST=trixie" && exit 1)
	@test -n "$(DIST)" || (echo "DIST required, e.g. DIST=trixie" && exit 1)
	@case " $(DOCKERSHELF_SUITES) " in \
		*" $(DIST) "*) ;; \
		*) echo "DIST must be one of: $(DOCKERSHELF_SUITES)"; exit 1;; \
	esac
	@cd "$(WORKSPACE)/node$(NODE)" && ../node-pipeline/meta-gbp materialize "$(DIST)"

build: bootstrap build-tools-image
	@test -n "$(NODE)" || (echo "NODE required" && exit 1)
	@mkdir -p "$(DIST_DIR)"
	@cd "$(WORKSPACE)/node$(NODE)" && ../node-pipeline/meta-gbp build
	@echo "Packages written to $(DIST_DIR)/"

publish:
	@test -n "$(DIST)" || (echo "DIST required, e.g. make publish DIST=trixie" && exit 1)
	@shopt -s nullglob; debs=("$(DIST_DIR)"/*.deb); \
	if [ "$${#debs[@]}" -eq 0 ]; then \
		echo "No .deb files in $(DIST_DIR)/ — run make build first"; \
		exit 1; \
	fi; \
	echo "Publishing $${#debs[@]} package(s) to $(DOCKERSHELF_DEPLOY_USER)@$(DOCKERSHELF_DEPLOY_HOST):$(DOCKERSHELF_DEPLOY_INCOMING)/"; \
	rsync -av --progress "$${debs[@]}" \
		"$(DOCKERSHELF_DEPLOY_USER)@$(DOCKERSHELF_DEPLOY_HOST):$(DOCKERSHELF_DEPLOY_INCOMING)/"; \
	ssh "$(DOCKERSHELF_DEPLOY_USER)@$(DOCKERSHELF_DEPLOY_HOST)" \
		"REPO_ROOT=$(DOCKERSHELF_DEPLOY_DIR) INCOMING=$(DOCKERSHELF_DEPLOY_INCOMING) \
		/usr/local/bin/dockershelf-import-incoming $(DIST) || \
		bash -s $(DIST)" < "$(PIPELINE)/debian-repo-setup/import-incoming.sh"; \
	echo "Published to $(DOCKERSHELF_APT_URL) ($(DIST))"
