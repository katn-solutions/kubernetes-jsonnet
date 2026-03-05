// Test: namespaces/v0.libsonnet
local namespaces = import '../namespaces/v0.libsonnet';

local result = namespaces.resources(
  name='test-namespace',
  istio='enabled',
  sec_profile='restricted'
);

// Extract the resource (it's under a dynamic key)
local key = std.objectFields(result)[0];
local resource = result[key];

// Assertions
assert resource.kind == 'Namespace' : 'Wrong kind';
assert resource.apiVersion == 'v1' : 'Wrong apiVersion';
assert resource.metadata.name == 'test-namespace' : 'Wrong name';
assert resource.metadata.labels['istio-injection'] == 'enabled' : 'Wrong istio label';
assert resource.metadata.labels['pod-security.kubernetes.io/enforce'] == 'restricted' : 'Wrong security profile';

result
