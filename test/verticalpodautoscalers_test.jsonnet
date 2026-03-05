// Test: verticalpodautoscalers/v1.libsonnet
local vpas = import '../verticalpodautoscalers/v1.libsonnet';

// --- Test 1: Minimal Deployment VPA (no resource policy) ---
local minimal = vpas.resources(
  namespace='test-ns',
  name='my-app',
  targetKind='Deployment',
);

local minimal_key = 'test-ns-my-app-vpa.json';
local minimal_r = minimal[minimal_key];

assert minimal_r.kind == 'VerticalPodAutoscaler' : 'T1: Wrong kind';
assert minimal_r.apiVersion == 'autoscaling.k8s.io/v1' : 'T1: Wrong apiVersion';
assert minimal_r.metadata.name == 'my-app' : 'T1: Wrong name';
assert minimal_r.metadata.namespace == 'test-ns' : 'T1: Wrong namespace';
assert minimal_r.spec.targetRef.apiVersion == 'apps/v1' : 'T1: Wrong targetRef apiVersion';
assert minimal_r.spec.targetRef.kind == 'Deployment' : 'T1: Wrong targetRef kind';
assert minimal_r.spec.targetRef.name == 'my-app' : 'T1: Wrong targetRef name';
assert minimal_r.spec.updatePolicy.updateMode == 'Auto' : 'T1: Wrong default updateMode';
assert !std.objectHas(minimal_r.spec, 'resourcePolicy') : 'T1: Should not have resourcePolicy';
assert !std.objectHas(minimal_r.spec.updatePolicy, 'minReplicas') : 'T1: Should not have minReplicas';

// --- Test 2: Full Deployment VPA with all options ---
local full = vpas.resources(
  namespace='prod-01',
  name='account-service',
  targetKind='Deployment',
  updateMode='Auto',
  controlledValues='RequestsOnly',
  controlledResources=['cpu', 'memory'],
  minAllowed={ cpu: '5m', memory: '64Mi' },
  maxAllowed={ cpu: '2', memory: '4Gi' },
  minReplicas=2,
  evictionRequirements=[
    {
      changeRequirement: 'TargetHigherThanRequests',
      resources: ['cpu', 'memory'],
    },
  ],
);

local full_key = 'prod-01-account-service-vpa.json';
local full_r = full[full_key];

assert full_r.spec.updatePolicy.updateMode == 'Auto' : 'T2: Wrong updateMode';
assert full_r.spec.updatePolicy.minReplicas == 2 : 'T2: Wrong minReplicas';
assert std.length(full_r.spec.updatePolicy.evictionRequirements) == 1 : 'T2: Wrong evictionRequirements length';
assert full_r.spec.updatePolicy.evictionRequirements[0].changeRequirement == 'TargetHigherThanRequests' : 'T2: Wrong changeRequirement';

local full_cp = full_r.spec.resourcePolicy.containerPolicies[0];
assert full_cp.containerName == '*' : 'T2: Wrong containerName';
assert full_cp.controlledValues == 'RequestsOnly' : 'T2: Wrong controlledValues';
assert full_cp.controlledResources[0] == 'cpu' : 'T2: Wrong controlledResources';
assert full_cp.controlledResources[1] == 'memory' : 'T2: Wrong controlledResources';
assert full_cp.minAllowed.cpu == '5m' : 'T2: Wrong minAllowed cpu';
assert full_cp.minAllowed.memory == '64Mi' : 'T2: Wrong minAllowed memory';
assert full_cp.maxAllowed.cpu == '2' : 'T2: Wrong maxAllowed cpu';
assert full_cp.maxAllowed.memory == '4Gi' : 'T2: Wrong maxAllowed memory';

// --- Test 3: StatefulSet VPA ---
local sts = vpas.resources(
  namespace='dev-01',
  name='my-cache',
  targetKind='StatefulSet',
  updateMode='Off',
);

local sts_key = 'dev-01-my-cache-vpa.json';
local sts_r = sts[sts_key];

assert sts_r.spec.targetRef.kind == 'StatefulSet' : 'T3: Wrong targetRef kind';
assert sts_r.spec.updatePolicy.updateMode == 'Off' : 'T3: Wrong updateMode';

// --- Test 4: CPU-only VPA ---
local cpu_only = vpas.resources(
  namespace='dev-01',
  name='hasura',
  targetKind='Deployment',
  controlledValues='RequestsOnly',
  controlledResources=['cpu'],
  minAllowed={ cpu: '20m' },
  maxAllowed={ cpu: '4' },
);

local cpu_key = 'dev-01-hasura-vpa.json';
local cpu_r = cpu_only[cpu_key];
local cpu_cp = cpu_r.spec.resourcePolicy.containerPolicies[0];

assert cpu_cp.controlledResources[0] == 'cpu' : 'T4: Wrong controlledResources';
assert std.length(cpu_cp.controlledResources) == 1 : 'T4: Should only have cpu';
assert cpu_cp.minAllowed.cpu == '20m' : 'T4: Wrong minAllowed';
assert !std.objectHas(cpu_cp.minAllowed, 'memory') : 'T4: Should not have memory in minAllowed';

// --- Test 5: Custom targetApi ---
local custom = vpas.resources(
  namespace='dev-01',
  name='my-rollout',
  targetKind='Rollout',
  targetApi='argoproj.io/v1alpha1',
);

local custom_key = 'dev-01-my-rollout-vpa.json';
local custom_r = custom[custom_key];

assert custom_r.spec.targetRef.apiVersion == 'argoproj.io/v1alpha1' : 'T5: Wrong custom targetApi';
assert custom_r.spec.targetRef.kind == 'Rollout' : 'T5: Wrong custom targetKind';

// --- Test 6: InPlaceOrRecreate mode (1.5.0 feature) ---
local inplace = vpas.resources(
  namespace='dev-01',
  name='fast-resize',
  targetKind='Deployment',
  updateMode='InPlaceOrRecreate',
  controlledValues='RequestsOnly',
  minAllowed={ cpu: '10m', memory: '32Mi' },
  maxAllowed={ cpu: '1', memory: '2Gi' },
);

local inplace_key = 'dev-01-fast-resize-vpa.json';
local inplace_r = inplace[inplace_key];

assert inplace_r.spec.updatePolicy.updateMode == 'InPlaceOrRecreate' : 'T6: Wrong updateMode';

// --- Test 7: Per-container mode (disable VPA for sidecar) ---
local per_container = vpas.resources(
  namespace='dev-01',
  name='with-sidecar',
  targetKind='Deployment',
  containerName='istio-proxy',
  mode='Off',
);

local pc_key = 'dev-01-with-sidecar-vpa.json';
local pc_r = per_container[pc_key];
local pc_cp = pc_r.spec.resourcePolicy.containerPolicies[0];

assert pc_cp.containerName == 'istio-proxy' : 'T7: Wrong containerName';
assert pc_cp.mode == 'Off' : 'T7: Wrong mode';

// Return all results to prove they render
minimal + full + sts + cpu_only + custom + inplace + per_container
