# Jsonnet Kubernetes Libraries

**Production-tested Jsonnet libraries for Kubernetes resource generation**

Battle-tested factories extracted from a production fintech platform managing 73 microservices across 11 clusters.

## What's Included

### Data Stores
- **[postgres/](postgres/)** - PostgreSQL with TimescaleDB (CloudNativePG)
- **[clickhouse/](clickhouse/)** - ClickHouse analytics database
- **[neo4j/](neo4j/)** - Neo4j graph database
- **[minio/](minio/)** - MinIO S3-compatible object storage

### Streaming & Messaging
- **[kafkas/](kafkas/)** - Kafka clusters (Strimzi operator)
- **[kafkatopics/](kafkatopics/)** - Kafka topic management
- **[kafkausers/](kafkausers/)** - Kafka user/ACL management
- **[redises/](redises/)** - Redis (standalone, sentinel, cluster)

### GitOps & Flux
- **[gitrepositories/](gitrepositories/)** - Flux GitRepository CRDs
- **[kustomizations/](kustomizations/)** - Flux Kustomization CRDs
- **[imagerepositories/](imagerepositories/)** - Flux ImageRepository CRDs
- **[imagepolicies/](imagepolicies/)** - Flux ImagePolicy CRDs
- **[imageupdateautomations/](imageupdateautomations/)** - Flux ImageUpdateAutomation CRDs

### Secrets Management
- **[vaults/](vaults/)** - Vault Secrets Operator (VaultAuth, VaultStaticSecret)
- **[secrets/](secrets/)** - Kubernetes Secret resources
- **[synced_secrets/](synced_secrets/)** - Vault-synced secrets with auto-restart

### GraphQL
- **[hasura/](hasura/)** - Hasura GraphQL Engine
- **[hasura-operator/](hasura-operator/)** - Hasura Operator CRDs

### Monitoring & Observability
- **[prometheusrules/](prometheusrules/)** - Prometheus alerting rules
- **[servicemonitors/](servicemonitors/)** - Prometheus ServiceMonitor CRDs
- **[podmonitors/](podmonitors/)** - Prometheus PodMonitor CRDs

### Autoscaling
- **[horizontalpodautoscalers/](horizontalpodautoscalers/)** - HPA resources
- **[verticalpodautoscalers/](verticalpodautoscalers/)** - VPA resources
- **[scaledobjects/](scaledobjects/)** - KEDA ScaledObject CRDs

### Core Kubernetes
- **[namespaces/](namespaces/)** - Namespace with labels/annotations
- **[serviceaccounts/](serviceaccounts/)** - ServiceAccount resources
- **[configmaps/](configmaps/)** - ConfigMap resources
- **[clusterroles/](clusterroles/)** - ClusterRole RBAC
- **[clusterrolebindings/](clusterrolebindings/)** - ClusterRoleBinding RBAC
- **[roles/](roles/)** - Role RBAC
- **[rolebindings/](rolebindings/)** - RoleBinding RBAC

### Services
- **[standard-service/](standard-service/)** - Standard Kubernetes Service
- **[headless-service/](headless-service/)** - Headless Service for StatefulSets
- **[headlessdeployments/](headlessdeployments/)** - Headless Deployment pattern

### Other
- **[kubeletcertapprovers/](kubeletcertapprovers/)** - Kubelet certificate approval

## Installation

### Using jsonnet-bundler (Recommended)

```bash
# Install jsonnet-bundler
go install -a github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb@latest

# Initialize your project
mkdir my-project && cd my-project
jb init

# Install this library
jb install github.com/katn-solutions/jsonnet-k8s-libsonnet@main

# Libraries are now in vendor/
```

### Manual Installation

```bash
git clone https://github.com/katn-solutions/jsonnet-k8s-libsonnet.git
export JSONNET_PATH="$(pwd)/jsonnet-k8s-libsonnet"
```

## Usage

### Basic Example - PostgreSQL Cluster

```jsonnet
local postgres = import 'postgres/postgres-v2.libsonnet';

postgres.resources(
  namespace='production',
  name='main-db',
  replicas=3,
  storage_size='100Gi',
  storage_class='fast-ssd',
  resources={
    requests: { cpu: '2', memory: '8Gi' },
    limits: { cpu: '4', memory: '16Gi' },
  },
)
```

Generates:
- PostgreSQL Cluster CRD
- Backup configuration
- Monitoring ServiceMonitor
- Connection pooler

### Basic Example - Kafka Cluster

```jsonnet
local kafka = import 'kafkas/v1.libsonnet';

kafka.resources(
  namespace='production',
  name='events',
  replicas=3,
  zookeeper_replicas=3,
  storage_size='500Gi',
  resources={
    requests: { cpu: '2', memory: '4Gi' },
    limits: { cpu: '4', memory: '8Gi' },
  },
)
```

Generates:
- Kafka Cluster (Strimzi)
- ZooKeeper ensemble
- Metrics exporters
- ServiceMonitors

### Basic Example - Flux Kustomization

```jsonnet
local kustomizations = import 'kustomizations/v0.libsonnet';

kustomizations.resources(
  name='apps-production',
  namespace='flux-system',
  repo='platform-repo',
  repo_namespace='flux-system',
  path='./apps/resources/production',
  prune=true,
)
```

### Basic Example - Vault Secret Sync

```jsonnet
local synced_secrets = import 'synced_secrets/v1.libsonnet';

synced_secrets.resources(
  namespace='production',
  secrets=[
    {
      name: 'api-service',
      mount: 'prod',
      path: 'api-service',
      type: 'Opaque',
      restart_targets: [
        { kind: 'Deployment', name: 'api-service' },
      ],
    },
  ],
  vault_auth_name='default',
)
```

Generates:
- VaultStaticSecret CRD
- Kubernetes Secret (auto-synced from Vault)
- Deployment restart on secret rotation

## Library Versions

Each library uses semantic versioning via filename:

```
postgres/
├── v0.libsonnet    # Initial version
├── v1.libsonnet    # Added features, backwards compatible
└── v2.libsonnet    # Breaking changes or major refactor
```

**Recommendation:** Always import specific versions:
```jsonnet
local postgres_v2 = import 'postgres/postgres-v2.libsonnet';
```

This prevents breaking changes when upgrading the library.

## Design Philosophy

### 1. Factories, Not Templates

Libraries are **functions** that return Kubernetes resources:

```jsonnet
// Good - Factory function
{
  resources(namespace, name, replicas):: {
    deployment: { /* ... */ },
    service: { /* ... */ },
  }
}

// Bad - Template with placeholders
{
  deployment: {
    metadata: {
      name: '${NAME}',  // Don't do this
    }
  }
}
```

### 2. Sensible Defaults

Libraries should work with minimal configuration:

```jsonnet
// Minimal usage
postgres.resources(
  namespace='prod',
  name='db',
)

// Override when needed
postgres.resources(
  namespace='prod',
  name='db',
  replicas=5,              // Custom
  storage_size='1Ti',      // Custom
  backup_retention='30d',  // Custom
)
```

### 3. Return Objects for Composition

```jsonnet
{
  resources(...):: {
    deployment: { /* ... */ },
    service: { /* ... */ },
    configmap: { /* ... */ },
  }
}

// Compose multiple resources
local db = postgres.resources(...);
local cache = redis.resources(...);

db + cache  // Merge objects
```

### 4. Version When Breaking

Never change existing library behavior - create new version:

```jsonnet
// v1.libsonnet (old)
{ resources(namespace, name):: { /* ... */ } }

// v2.libsonnet (new - different API)
{ resources(config):: { /* ... */ } }
```

Users can migrate on their timeline.

## Development

### Running Tests

```bash
# Test a library generates valid JSON
jsonnet -J vendor example.jsonnet

# Convert to YAML
jsonnet -J vendor example.jsonnet | gojsontoyaml
```

### Adding a New Library

1. Create directory: `mkdir my-resource/`
2. Create `my-resource/v0.libsonnet`
3. Add `my-resource/README.md` with examples
4. Test with real cluster
5. Submit PR

### Breaking Changes

When making breaking changes:

1. Create new version: `my-resource/v1.libsonnet`
2. Keep old version: `my-resource/v0.libsonnet`
3. Document migration in README
4. Bump library version tag

## Compatibility

**Tested with:**
- Kubernetes 1.27+
- Flux CD v2.0+
- Strimzi Kafka Operator 0.38+
- CloudNativePG 1.20+
- Vault Secrets Operator 0.4+

## Contributing

Contributions welcome! Please:

1. Test with real Kubernetes cluster
2. Follow existing patterns (factory functions)
3. Add README with examples
4. Version properly (v0, v1, v2)
5. Submit PR with description

## License

MIT License - See [LICENSE](LICENSE) for details

## Credits

Developed by [Nik Ogura](https://github.com/nikogura) with 25+ years experience across Apple, AWS, Scribd, and startups.

---

**This is production code, not theory.**
