// Test: kustomizations/v0.libsonnet
local kustomization = import '../kustomizations/v0.libsonnet';

local result = kustomization.resources(
  name='apps-production',
  namespace='flux-system',
  repo='platform-repo',
  repo_namespace='flux-system',
  path='./apps/production',
  prune=true,
  target_namespace='production'
);

// Assertions
local key = std.objectFields(result)[0];
assert std.objectHas(result, key) : 'Missing kustomization resource';
assert result[key].kind == 'Kustomization' : 'Wrong kind';
assert result[key].apiVersion == 'kustomize.toolkit.fluxcd.io/v1' : 'Wrong apiVersion';
assert result[key].metadata.name == 'apps-production' : 'Wrong name';
assert result[key].metadata.namespace == 'flux-system' : 'Wrong namespace';
assert result[key].spec.path == './apps/production' : 'Wrong path';
assert result[key].spec.prune == true : 'Wrong prune setting';
assert result[key].spec.sourceRef.kind == 'GitRepository' : 'Wrong sourceRef kind';
assert result[key].spec.sourceRef.name == 'platform-repo' : 'Wrong sourceRef name';
assert result[key].spec.targetNamespace == 'production' : 'Wrong targetNamespace';

result
