// Test: serviceaccounts/v0.libsonnet
local serviceaccounts = import '../serviceaccounts/v0.libsonnet';

local result = serviceaccounts.resources(
  name='test-sa',
  namespace='test',
  aws_account_number='123456789012',
  iam_role_name='test-role'
);

// Extract the resource (it's under a dynamic key)
local key = std.objectFields(result)[0];
local resource = result[key];

// Assertions
assert resource.kind == 'ServiceAccount' : 'Wrong kind';
assert resource.apiVersion == 'v1' : 'Wrong apiVersion';
assert resource.metadata.name == 'test-sa' : 'Wrong name';
assert resource.metadata.namespace == 'test' : 'Wrong namespace';
assert std.objectHas(resource.metadata, 'annotations') : 'Missing annotations';
assert resource.metadata.annotations['eks.amazonaws.com/role-arn'] == 'arn:aws:iam::123456789012:role/test-role' : 'Wrong IAM role';

result
