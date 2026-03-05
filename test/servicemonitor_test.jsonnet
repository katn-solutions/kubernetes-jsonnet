// Test: servicemonitors/v0.libsonnet
local servicemonitor = import '../servicemonitors/v0.libsonnet';

local result = servicemonitor.resources(
  name='test-monitor',
  namespace='monitoring',
  labels={ app: 'test', prometheus: 'main' },
  matchLabels={ app: 'test' }
);

// Assertions
local key = std.objectFields(result)[0];
assert std.objectHas(result, key) : 'Missing servicemonitor resource';
assert result[key].kind == 'ServiceMonitor' : 'Wrong kind';
assert result[key].apiVersion == 'monitoring.coreos.com/v1' : 'Wrong apiVersion';
assert result[key].metadata.name == 'test-monitor' : 'Wrong name';
assert result[key].metadata.namespace == 'monitoring' : 'Wrong namespace';
assert result[key].metadata.labels.app == 'test' : 'Wrong label';
assert result[key].spec.selector.matchLabels.app == 'test' : 'Wrong matchLabels';
assert std.length(result[key].spec.endpoints) == 1 : 'Wrong number of endpoints';
assert result[key].spec.endpoints[0].port == 'http' : 'Wrong endpoint port';
assert result[key].spec.endpoints[0].interval == '30s' : 'Wrong interval';
assert result[key].spec.endpoints[0].path == '/metrics' : 'Wrong path';

result
