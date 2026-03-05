// Test: prometheusrules/v0.libsonnet
local prometheusrule = import '../prometheusrules/v0.libsonnet';

local result = prometheusrule.resources(
  app_name='test-app',
  component_name='api',
  rule_name='high-error-rate',
  namespace='monitoring',
  cluster='prod',
  alert='HighErrorRate',
  message='Error rate is above 5% for {{ $labels.service }}',
  expression='rate(http_requests_total{status=~"5.."}[5m]) > 0.05',
  duration='5m',
  severity='warning'
);

// Assertions
local key = std.objectFields(result)[0];
assert std.objectHas(result, key) : 'Missing prometheusrule resource';
assert result[key].kind == 'PrometheusRule' : 'Wrong kind';
assert result[key].apiVersion == 'monitoring.coreos.com/v1' : 'Wrong apiVersion';
assert result[key].metadata.name == 'test-app-high-error-rate' : 'Wrong name';
assert result[key].metadata.namespace == 'monitoring' : 'Wrong namespace';
assert result[key].metadata.labels.app == 'test-app' : 'Wrong app label';
assert result[key].metadata.labels.component == 'api' : 'Wrong component label';
assert std.length(result[key].spec.groups) == 1 : 'Wrong number of groups';
assert std.length(result[key].spec.groups[0].rules) == 1 : 'Wrong number of rules';
assert result[key].spec.groups[0].rules[0].alert == 'HighErrorRate' : 'Wrong alert name';
assert result[key].spec.groups[0].rules[0]['for'] == '5m' : 'Wrong duration';
assert result[key].spec.groups[0].rules[0].labels.severity == 'warning' : 'Wrong severity';

result
