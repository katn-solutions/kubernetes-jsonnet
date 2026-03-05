// Test: redises/standalone-v0.libsonnet
local redis = import '../redises/standalone-v0.libsonnet';

local result = redis.resources(
  account_number='123456789012',
  region='us-east-1',
  cluster='test-cluster',
  environment='dev',
  namespace_name='test',
  resource_name='test-redis',
  storage='10Gi',
  requested_resources={
    requests: { cpu: '100m', memory: '256Mi' },
    limits: { cpu: '1', memory: '1Gi' },
  }
);

// Find the Redis resource (multiple resources are returned)
local redis_keys = [k for k in std.objectFields(result) if std.endsWith(k, 'redis.json')];
assert std.length(redis_keys) > 0 : 'No Redis resource found';
local redis_key = redis_keys[0];
local redis_resource = result[redis_key];

// Assertions - verify structure
assert redis_resource.kind == 'Redis' : 'Wrong kind: ' + redis_resource.kind;
assert redis_resource.apiVersion == 'redis.redis.opstreelabs.in/v1beta2' : 'Wrong apiVersion';
assert redis_resource.metadata.name == 'test-redis' : 'Wrong name';
assert redis_resource.metadata.namespace == 'test' : 'Wrong namespace';

result
