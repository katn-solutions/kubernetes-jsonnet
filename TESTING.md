# Jsonnet Library Testing Guide

This document describes the linting and testing strategy for the kubernetes-jsonnet library.

## Overview

The library uses multiple layers of validation to ensure code quality and correctness:

1. **Formatting** - Consistent code style with `jsonnetfmt`
2. **Linting** - Static analysis with `jsonnet-lint`
3. **Parameter Validation** - Runtime type checking with `validate-libsonnet`
4. **Manifest Validation** - Kubernetes schema validation with `kubeconform`

## Installation

### Required Tools

```bash
# Install jsonnet toolchain
go install github.com/google/go-jsonnet/cmd/jsonnet@latest
go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest
go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest

# Install kubeconform for manifest validation
# Download from: https://github.com/yannh/kubeconform/releases
# Or use package manager:
brew install kubeconform  # macOS
```

### Optional: Parameter Validation Library

```bash
# For enhanced parameter validation
jb install github.com/crdsonnet/validate-libsonnet@master
```

## Running Tests

### Format Check

```bash
make fmt
```

Formats all `.jsonnet` and `.libsonnet` files consistently:
- 2-space indentation
- Maximum 2 blank lines
- Single-quoted strings
- Slash-style comments (`//`)

### Linting

```bash
make lint
```

The linter checks for:
- **Unused variables** - Variables declared but never used
- **Function signature errors** - Wrong number of arguments or invalid named parameters
- **Syntax errors** - Invalid jsonnet syntax
- **Undeclared variables** - References to undefined variables
- **Infinite loops** - Endlessly looping constructs (e.g., `local x = x + 1`)

**Example lint error**:
```
postgres/postgres-v0.libsonnet:45:3-45:22: Function expects 3 parameters but 2 arguments were given
```

### Running All Checks

```bash
make all
```

Runs formatting, linting, and tests in sequence.

## Parameter Validation

### Built-in Validation

Jsonnet's type system provides basic parameter validation:

**Required vs Optional Parameters**:
```jsonnet
// Required parameter (no default)
resources(namespace, replicas)::

// Optional parameter (has default)
resources(namespace, replicas=3)::
```

**Named Arguments** (enforced by jsonnet-lint):
```jsonnet
// ✓ Correct - all parameters provided
postgres.resources('prod', 3, '10Gi')

// ✗ Error - missing required parameter
postgres.resources('prod', 3)

// ✓ Correct - using named arguments for clarity
postgres.resources(
  namespace='prod',
  replicas=3,
  storage='10Gi'
)
```

### Enhanced Validation with validate-libsonnet

For stricter type checking, use the `validate-libsonnet` library:

```jsonnet
local validate = import 'github.com/crdsonnet/validate-libsonnet/main.libsonnet';

local resources(
  namespace,
  replicas,
  storage,
)::
  // Validate parameters before use
  assert validate.checkParameters({
    namespace: std.isString(namespace) && std.length(namespace) > 0,
    replicas: std.isNumber(replicas) && replicas > 0,
    storage: std.isString(storage) && std.length(storage) > 0,
  });

  // Function implementation
  { /* ... */ }
```

This provides runtime validation with clear error messages:
```
RUNTIME ERROR: Parameter validation failed: replicas must be a positive number
```

## Kubernetes Manifest Validation

After generating YAML from jsonnet, validate against Kubernetes schemas:

```bash
# Validate specific cluster
cd kubernetes-gitops-framework
make validate-cluster CLUSTER=prod-01

# Validate all clusters
make validate-all
```

**What it checks**:
- Valid Kubernetes API versions
- Required fields present
- Field types correct
- Enum values valid
- CRD schemas (if provided)

**Example validation error**:
```
cluster/prod-01/deployment.yaml - Deployment default/app - INVALID
  spec.replicas: Invalid type. Expected: integer, given: string
```

## Writing Tests

### Test File Structure

Create test files with `_test.jsonnet` suffix:

```
test/
├── postgres_test.jsonnet
├── secrets_test.jsonnet
└── standard_service_test.jsonnet
```

### Example Test

```jsonnet
// test/postgres_test.jsonnet
local postgres = import '../postgres/postgres-v1.libsonnet';

local testBasicCluster =
  local result = postgres.resources(
    account_number='123456789',
    region='us-east-1',
    cluster='prod-01',
    environment='production',
    namespace_name='database',
    app_name='myapp-pg',
    app_restore_from='',
    app_replicas=3,
    app_storage='100Gi',
    app_resources={},
    app_parameters={},
    app_backup_schedule='0 2 * * *',
    app_backup_retention='30d',
    app_backup_s3_bucket='myorg-db-backups-prod',
    hasura_restore_from='',
    hasura_replicas=2,
    hasura_storage='20Gi',
    hasura_resources={},
    hasura_parameters={},
    hasura_backup_schedule='0 3 * * *',
    hasura_backup_retention='30d',
    hasura_backup_s3_bucket='myorg-hasura-backups-prod',
    roles=['app_user', 'readonly'],
  );

  // Assertions
  assert std.objectHas(result, 'myapp-pg') : 'Missing app cluster';
  assert std.objectHas(result, 'myapp-pg-hasura') : 'Missing hasura cluster';
  assert result['myapp-pg'].spec.instances == 3 : 'Wrong replica count';

  // Return success indicator
  { success: true };

// Run test
testBasicCluster
```

Run with:
```bash
jsonnet test/postgres_test.jsonnet
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Lint and Test

on: [push, pull_request]

jobs:
  jsonnet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'

      - name: Install jsonnet tools
        run: |
          go install github.com/google/go-jsonnet/cmd/jsonnet@latest
          go install github.com/google/go-jsonnet/cmd/jsonnet-lint@latest
          go install github.com/google/go-jsonnet/cmd/jsonnetfmt@latest

      - name: Lint jsonnet
        working-directory: kubernetes-jsonnet
        run: make lint

      - name: Run tests
        working-directory: kubernetes-jsonnet
        run: make test

  kubernetes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install kubeconform
        run: |
          wget https://github.com/yannh/kubeconform/releases/latest/download/kubeconform-linux-amd64.tar.gz
          tar xf kubeconform-linux-amd64.tar.gz
          sudo mv kubeconform /usr/local/bin/

      - name: Validate manifests
        working-directory: kubernetes-gitops-framework
        run: make validate-all
```

## Common Linting Issues

### Unused Variables

```jsonnet
// ✗ Error: unused variable
local postgres = import 'postgres/v1.libsonnet';
local secrets = import 'secrets/v0.libsonnet';

postgres.resources(...)  // secrets never used
```

**Fix**: Remove unused imports or use them.

### Function Signature Mismatch

```jsonnet
// Function expects 3 parameters
resources(namespace, replicas, storage)::

// ✗ Error: only 2 provided
resources('prod', 3)

// ✓ Fix: provide all required parameters
resources('prod', 3, '10Gi')
```

### Infinite Loop Detection

```jsonnet
// ✗ Error: infinite loop
local x = x + 1;

// ✓ Fix: use proper recursion or iteration
local x = 5;
```

## Best Practices

1. **Always use named parameters** for functions with more than 3 parameters
2. **Validate inputs early** at function entry points
3. **Write tests** for all factory functions
4. **Run linting locally** before committing
5. **Validate generated YAML** before applying to clusters
6. **Use consistent formatting** by running `make fmt` regularly
7. **Document parameter types** in comments or docstrings

## Enforcing Named Parameters

The `jsonnet-lint` tool validates function calls, ensuring:

- All required parameters are provided
- Named arguments match function parameter names
- No extra arguments are passed

**Example enforcement**:

```jsonnet
// Function definition
resources(
  namespace,
  replicas,
  storage,
  backup_s3_bucket,  // Required parameter
)::

// ✗ Lint error: missing required parameter
resources('prod', 3, '10Gi')

// ✓ Passes lint: all parameters provided
resources('prod', 3, '10Gi', 'myorg-backups')

// ✓ Also passes: named arguments for clarity
resources(
  namespace='prod',
  replicas=3,
  storage='10Gi',
  backup_s3_bucket='myorg-backups'
)
```

This ensures that the S3 bucket parameterization changes (and other required parameters) cannot be accidentally omitted.

## Summary

| Tool | Purpose | Command |
|------|---------|---------|
| `jsonnetfmt` | Format code | `make fmt` |
| `jsonnet-lint` | Static analysis | `make lint` |
| `jsonnet` | Run tests | `make test` |
| `kubeconform` | Validate K8s YAML | `make validate-all` |
| `validate-libsonnet` | Runtime type checking | (library import) |

For questions or issues, check:
- Jsonnet docs: https://jsonnet.org/
- go-jsonnet linter: https://github.com/google/go-jsonnet/tree/master/linter
- kubeconform: https://github.com/yannh/kubeconform
