############################################################################
# Variables
############################################################################

# Since we rely on paths relative to the makefile location, abort if make isn't being run from there.
$(if $(findstring /,$(MAKEFILE_LIST)),$(error Please only invoke this makefile from the directory it resides in))

# SHELL defines the shell that the Makefile uses.
# We also set -o pipefail so that if a previous command in a pipeline fails, a command fails.
# http://redsymbol.net/articles/unofficial-bash-strict-mode
SHELL := /bin/bash -o errexit -o nounset

PYTHON := python3
NPM := npm

CLUSTER_NAME := backend-java-patterns
CLUSTER_NAMESPACE := webapp

VENV_NAME := venv
RELEASE_NAME := release
GH_PAGES_NAME := site

# Set V=1 on the command line to turn off all suppression. Many trivial
# commands are suppressed with "@", by setting V=1, this will be turned off.
ifeq ($(V),1)
	AT :=
else
	AT := @
endif

IMAGE ?= styled-java-patterns
OKTETO_IMAGE ?= okteto/$(IMAGE)
DOCKER_IMAGE ?= alexanderr/$(IMAGE)
TAG ?= latest

# UNAME_OS stores the value of uname -s.
UNAME_OS := $(shell uname -s)
# UNAME_ARCH stores the value of uname -m.
UNAME_ARCH := $(shell uname -m)
# ROOT_DIR stored git root directory
ROOT_DIR=$(git rev-parse --show-toplevel)
# ORIGINAL_BRANCH stored git branch name
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# TMP_BASE is the base directory used for TMP.
# Use TMP and not TMP_BASE as the temporary directory.
TMP_BASE := .tmp
# TMP_COVERAGE is where we store code coverage files.
TMP_COVERAGE := $(TMP_BASE)/coverage

UTILS := docker tilt helm
# Make sure that all required utilities can be located.
UTIL_CHECK := $(or $(shell which $(UTILS) >/dev/null && echo 'ok'),$(error Did you forget to install `docker` and `tilt` after cloning the repo? At least one of the required supporting utilities not found: $(UTILS)))
DIRS := $(shell ls -ad -- */)

# Run all by default when "make" is invoked.
.DEFAULT_GOAL := list

############################################################################
# Common
############################################################################

# Default target (by virtue of being the first non '.'-prefixed in the file).
.PHONY: _no-target-specified
_no-target-specified:
	$(error Please specify the target to make - `make list` shows targets)

# Create virtual environment.
.PHONY: _venv
_venv:
	virtualenv $(VENV_NAME)
	. $(VENV_NAME)/bin/activate
	@echo
	@echo "Virtual env created. The source pages are in $(VENV_NAME) directory."

# Create help information.
.PHONY: help
help:
	@echo
	@echo "Please use \`make <target>' where <target> is one of"
	@echo "  all       				to run linting & format tasks"
	@echo "  clean     				to remove temporary directories"
	@echo "  deps 						to install dependencies"
	@echo "  dirs     				to list directories"
	@echo "  docker-build     to build docker image"
	@echo "  docker-start   	to start docker image"
	@echo "  docker-stop     	to stop docker image"
	@echo "  gh-pages  				to create new version of documentation and publish on GitHub pages"
	@echo "  helm-dev    			to lint and create helm package"
	@echo "  helm-lint       	to lint helm charts"
	@echo "  helm-package     to package helm charts"
	@echo "  helm-start      	to run k8s cluster"
	@echo "  helm-stop   			to stop k8s cluster"
	@echo "  help 						to list all make targets with description"
	@echo "  install-pip 			to install python pip module"
	@echo "  list       			to list all make targets"
	@echo "  local-build      to build documentation locally"
	@echo "  local-run    		to run documentation locally"
	@echo "  okteto      			to build okteto image"
	@echo "  tilt-start    		to start development k8s cluster"
	@echo "  tilt-stop    		to stop development k8s cluster"
	@echo "  venv-build       to build documentation in virtual environment"
	@echo "  venv-run  				to run documentation in virtual environment"
	@echo "  versions  				to list commands versions"
	@echo

# Lists all targets defined in this makefile.
.PHONY: list
list:
	$(AT)$(MAKE) -pRrn : -f $(MAKEFILE_LIST) 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | command grep -v -e '^[^[:alnum:]]' -e '^$@$$command ' | sort

# Lists all dirs.
.PHONY: dirs
dirs:
	echo "$(DIRS)"
	@echo
	@echo "Directory list finished."

# Run version command.
.PHONY: versions
versions:
	$(AT) echo
	docker --version
	$(AT) echo
	tilt version
	$(AT) echo
	helm version
	$(AT) echo
	@echo
	@echo "Versions list finished."

# Clean removes all temporary files.
.PHONY: clean
clean:
	rm -rf $(TMP_BASE)
	rm -rf $(RELEASE_NAME)
	rm -rf $(GH_PAGES_NAME)
	rm -rf $(VENV_NAME)
	@echo
	@echo "Clean finished."

# Ensures that the git workspace is clean.
.PHONY: _ensure-clean
_ensure-clean:
	$(AT)[ -z "$$((git status --porcelain --untracked-files=no || echo err) | command grep -v 'CHANGELOG.md')" ] || { echo "Workspace is not clean; please commit changes first." >&2; exit 2; }

# Ensure docker tag command.
.PHONY: _ensure-docker-tag
_ensure-docker-tag:
ifndef DOCKER_TAG
	$(error Please invoke with `make DOCKER_TAG=<tag> docker-build`)
endif

# Run docker build command.
.PHONY: docker-build
docker-build: _ensure-docker-tag
	chmod +x ./scripts/docker-build.sh
	./scripts/docker-build.sh $(DOCKER_TAG)

# Run docker start command.
.PHONY: docker-start
docker-start:
	chmod +x ./scripts/docker-compose-start.sh
	./scripts/docker-compose-start.sh

# Run docker stop command.
.PHONY: docker-stop
docker-stop:
	chmod +x ./scripts/docker-compose-stop.sh
	./scripts/docker-compose-stop.sh

# Run tilt start command.
.PHONY: tilt-start
tilt-start:
	tilt up

# Run tilt stop command.
.PHONY: tilt-stop
tilt-stop:
	tilt down --delete-namespaces

# Run helm lint command.
.PHONY: helm-lint
helm-lint:
	helm lint charts --values charts/values.yaml

# Run helm start command.
.PHONY: helm-start
helm-start:
	helm upgrade --install $(CLUSTER_NAME) -f charts/values.yaml --create-namespace --namespace $(CLUSTER_NAMESPACE) charts

# Run helm stop command.
.PHONY: helm-stop
helm-stop:
	helm uninstall $(CLUSTER_NAME) --namespace $(CLUSTER_NAMESPACE)

# Run helm package command.
.PHONY: helm-package
helm-package:
	mkdir -p $(RELEASE_NAME)/charts
	helm package charts --dependency-update --destination $(RELEASE_NAME)/charts

# Run helm dev command.
.PHONY: helm-dev
helm-dev: clean helm-lint helm-package

# Run okteto build command.
.PHONY: okteto
okteto:
	okteto build -t $(DOCKER_IMAGE) .
	okteto build -t $(OKTETO_IMAGE) .

# Install pip command.
.PHONY: install-pip
install-pip:
	wget --no-check-certificate https://bootstrap.pypa.io/get-pip.py -O $(TMPDIR)/get-pip.py
	$(PYTHON) $(TMPDIR)/get-pip.py
	@echo
	@echo "Pip installed."

# Run local build command.
.PHONY: local-build
local-build:
	$(PYTHON) -m pip install -r ./docs/requirements.txt --disable-pip-version-check
	$(PYTHON) -m mkdocs build --clean --config-file mkdocs.yml

# Run local run command.
.PHONY: local-run
local-run: local-build
	$(PYTHON) -m mkdocs serve --verbose --dirtyreload

# Run venv build command.
.PHONY: venv-build
venv-build: _venv
	$(VENV_NAME)/bin/python3 -m pip install -r ./docs/requirements.txt --disable-pip-version-check --no-cache-dir --prefer-binary
	$(VENV_NAME)/bin/python3 -m mkdocs build --clean --config-file mkdocs.yml
	@echo
	@echo "Build finished. The source pages are in $(VENV_NAME) directory."
	exit

# Run venv run command.
.PHONY: venv-run
venv-run: venv-build
	$(VENV_NAME)/bin/python3 -m mkdocs serve --verbose --dirtyreload

# Run github pages deploy command.
.PHONY: gh-pages
gh-pages:
	$(PYTHON) -m mkdocs --verbose gh-deploy --force --remote-branch gh-pages
	@echo
	@echo "GitHub pages generated."

# Run npm install command.
.PHONY: deps
deps:
	$(NPM) install
	@echo
	@echo "Install finished."

# Run npm all command.
.PHONY: all
all:
	$(NPM) run all
	@echo
	@echo "Build finished."
