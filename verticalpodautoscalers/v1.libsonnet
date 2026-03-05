/*
  VPA v1 factory - supports VPA CRD v1.5.0 features.

  Usage:

    local vpas = import 'verticalpodautoscalers/v1.libsonnet';

    // Minimal: unconstrained VPA for a Deployment
    vpas.resources(
      namespace='prod-01',
      name='my-service',
      targetKind='Deployment',
    )

    // Full: constrained VPA with all options
    vpas.resources(
      namespace='prod-01',
      name='my-service',
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
    )

    // CPU-only VPA
    vpas.resources(
      namespace='prod-01',
      name='hasura',
      targetKind='Deployment',
      updateMode='Auto',
      controlledValues='RequestsOnly',
      controlledResources=['cpu'],
      minAllowed={ cpu: '20m' },
      maxAllowed={ cpu: '4' },
    )
*/
{
  resources(
    namespace,
    name,
    targetKind,
    targetApi='apps/v1',
    updateMode='Auto',
    controlledValues=null,
    controlledResources=null,
    minAllowed=null,
    maxAllowed=null,
    containerName='*',
    mode=null,
    minReplicas=null,
    evictionRequirements=null,
  )::
    local vpa_output = '%s-%s-vpa.json' % [namespace, name];

    local hasContainerPolicy =
      controlledValues != null
      || controlledResources != null
      || minAllowed != null
      || maxAllowed != null
      || mode != null;

    local containerPolicy =
      { containerName: containerName }
      + (if controlledValues != null then { controlledValues: controlledValues } else {})
      + (if controlledResources != null then { controlledResources: controlledResources } else {})
      + (if minAllowed != null then { minAllowed: minAllowed } else {})
      + (if maxAllowed != null then { maxAllowed: maxAllowed } else {})
      + (if mode != null then { mode: mode } else {});

    local updatePolicy =
      { updateMode: updateMode }
      + (if minReplicas != null then { minReplicas: minReplicas } else {})
      + (if evictionRequirements != null then { evictionRequirements: evictionRequirements } else {});

    {
      [vpa_output]: {
        apiVersion: 'autoscaling.k8s.io/v1',
        kind: 'VerticalPodAutoscaler',
        metadata: {
          name: name,
          namespace: namespace,
        },
        spec: {
          targetRef: {
            apiVersion: targetApi,
            kind: targetKind,
            name: name,
          },
          updatePolicy: updatePolicy,
        } + (if hasContainerPolicy then {
               resourcePolicy: {
                 containerPolicies: [containerPolicy],
               },
             } else {}),
      },
    },
}
