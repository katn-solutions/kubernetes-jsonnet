// Test: gitrepositories/v0.libsonnet
local gitrepo = import '../gitrepositories/v0.libsonnet';

local result = gitrepo.resources(
  name='platform-repo',
  namespace_name='flux-system',
  interval='5m',
  ref={ branch: 'main' },
  secret_ref={ name: 'git-credentials' },
  url='https://github.com/example/platform'
);

// Assertions
local key = std.objectFields(result)[0];
assert std.objectHas(result, key) : 'Missing gitrepository resource';
assert result[key].kind == 'GitRepository' : 'Wrong kind';
assert result[key].apiVersion == 'source.toolkit.fluxcd.io/v1' : 'Wrong apiVersion';
assert result[key].metadata.name == 'platform-repo' : 'Wrong name';
assert result[key].metadata.namespace == 'flux-system' : 'Wrong namespace';
assert result[key].spec.interval == '5m' : 'Wrong interval';
assert result[key].spec.url == 'https://github.com/example/platform' : 'Wrong URL';
assert result[key].spec.ref.branch == 'main' : 'Wrong branch';
assert result[key].spec.recurseSubmodules == false : 'Wrong recurseSubmodules default';

result
