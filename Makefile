# Kubernetes Jsonnet Library - Linting and Testing
#
# Usage:
#   make fmt              - Format all jsonnet files
#   make lint             - Run jsonnet linter
#   make test             - Run tests
#   make validate         - Validate generated Kubernetes manifests
#   make all              - Format, lint, and test
#
# Requirements:
#   go install github.com/google/go-jsonnet/cmd/jsonnet@latest
#   go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest
#   go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest

JSONNET_FMT := jsonnetfmt -n 2 --max-blank-lines 2 --string-style s --comment-style s
JSONNET_LINT := jsonnet-lint
JSONNET := jsonnet

.PHONY: help all fmt lint test clean

help:
	@echo "Available targets:"
	@echo "  make fmt      - Format all jsonnet files in place"
	@echo "  make lint     - Lint all jsonnet files"
	@echo "  make test     - Run jsonnet tests"
	@echo "  make all      - Run fmt, lint, and test"
	@echo "  make clean    - Remove generated test files"
	@echo ""
	@echo "Requirements:"
	@echo "  go install github.com/google/go-jsonnet/cmd/jsonnet@latest"
	@echo "  go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest"
	@echo "  go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest"

all: fmt lint test

# Format all jsonnet files
fmt:
	@echo "Formatting jsonnet files..."
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNET_FMT) -i
	@echo "✓ Formatting complete"

# Lint all jsonnet files
lint:
	@echo "Linting jsonnet files..."
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		while read -r file; do \
			echo "  Linting $$file"; \
			$(JSONNET_LINT) "$$file" || exit 1; \
		done
	@echo "✓ Linting complete"

# Run tests (looks for *_test.jsonnet files)
test:
	@echo "Running jsonnet tests..."
	@if [ -d "test" ]; then \
		cd test && \
		for f in $$(find . -name '*_test.jsonnet' -print); do \
			echo "  Running test: $$f"; \
			$(JSONNET) "$$f" > /dev/null || exit 1; \
		done; \
		echo "✓ All tests passed"; \
	else \
		echo "ℹ No test directory found - skipping tests"; \
	fi

# Clean generated files
clean:
	@echo "Cleaning generated test files..."
	@find . -name '*.yaml.tmp' -delete
	@find . -name '*.json.tmp' -delete
	@echo "✓ Cleanup complete"

# Check if required tools are installed
check-tools:
	@echo "Checking for required tools..."
	@command -v $(JSONNET) >/dev/null 2>&1 || \
		(echo "✗ jsonnet not found. Install: go install github.com/google/go-jsonnet/cmd/jsonnet@latest" && exit 1)
	@command -v $(JSONNET_LINT) >/dev/null 2>&1 || \
		(echo "✗ jsonnet-lint not found. Install: go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest" && exit 1)
	@command -v jsonnetfmt >/dev/null 2>&1 || \
		(echo "✗ jsonnetfmt not found. Install: go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest" && exit 1)
	@echo "✓ All required tools installed"
