// Test: configmaps/v0.libsonnet
local configmaps = import '../configmaps/v0.libsonnet';

local result = configmaps.resources(
  namespace='test',
  name='test-config',
  data={
    key1: 'value1',
    key2: 'value2',
  }
);

// Extract the resource (it's under a dynamic key)
local key = std.objectFields(result)[0];
local resource = result[key];

// Assertions
assert resource.kind == 'ConfigMap' : 'Wrong kind';
assert resource.apiVersion == 'v1' : 'Wrong apiVersion';
assert resource.metadata.name == 'test-config' : 'Wrong name';
assert resource.metadata.namespace == 'test' : 'Wrong namespace';
assert resource.data.key1 == 'value1' : 'Wrong data value';
assert resource.data.key2 == 'value2' : 'Wrong data value';

result
