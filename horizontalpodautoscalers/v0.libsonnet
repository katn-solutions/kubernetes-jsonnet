{
  resources(
    name,
    namespace,
    min_replicas,
    max_replicas,
  )::

    local fmt_context = {
      name: name,
      namespace: namespace,
    };

    local output = '%s(namespace)s-%(app_name)s-%(deployment_name)s-autoscaler.json' % fmt_context;

    {
      [output]: {
        apiVersion: 'autoscaling/v2beta2',
        kind: 'HorizontalPodAutoscaler',
        metadata: {
          name: name,
          namespace: namespace,
        },
        spec: {
          scaleTargetRef: {
            apiVersion: 'apps/v1',
            kind: 'Deployment',
            name: name,
          },
          minReplicas: min_replicas,
          maxReplicas: max_replicas,
          metrics: [{
            type: 'Resource',
            resource: {
              name: 'cpu',
              target: {
                type: 'Utilization',
                averageUtilization: 85,
              },
            },
          }],
        },
      },
    },
}
