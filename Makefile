# Build the licensescan image. This image is used to scan source code for licenses.
#
# Usage:
#   make (reqs|reqs-test|reqs-all|test|image|push|clean)

# See https://www.gnu.org/software/make/manual/html_node/One-Shell.html#One-Shell
.ONESHELL:
SHELL := /bin/bash

VERSION?=''
OUTPUT_DIR?=.

.PHONY: binaries templates policies all

binaries:
	source ./build/build-include.sh -v $(VERSION) -o $(OUTPUT_DIR)
	build_binaries

templates:
	source ./build/build-include.sh -v $(VERSION) -o $(OUTPUT_DIR)
	build_templates

policies:
	source ./build/build-include.sh -v $(VERSION) -o $(OUTPUT_DIR)
	build_policies

all: binaries templates policies
