{
  resources(
    name,
    app_name,
    component_name,
    namespace_name,
    cluster,
    min_replicas,
    max_replicas,
    bootstrap_servers,
    consumer_group,
    topic,
    lag_threshold,
  )::

    local fmt_context = {
      name: name,
      app_name: app_name,
      component_name: component_name,
      namespace_name: namespace_name,
      cluster: cluster,

    };

    local scaled_object_output = '%(name)s-%(app_name)s-scaled-object.json' % fmt_context;
    local trigger_auth_output = '%(name)s-%(app_name)s-trigger-auth.json' % fmt_context;

    {
      [scaled_object_output]: {
        apiVersion: 'keda.sh/v1alpha1',
        kind: 'ScaledObject',
        metadata: {
          name: name,
          namespace: namespace_name,
        },
        spec: {
          scaleTargetRef: {
            apiVersion: 'apps/v1',
            kind: 'Deployment',
            name: app_name,
          },
          minReplicaCount: min_replicas,
          maxReplicaCount: max_replicas,
          triggers: [
            {
              type: 'kafka',
              metadata: {
                bootstrapServers: bootstrap_servers,
                consumerGroup: consumer_group,
                topic: topic,
                sasl: 'scram_sha512',
                tls: 'disable',
                username: app_name + '-kafka-user',
                lagThreshold: lag_threshold,
              },
            },
          ],
        },
      },
      [trigger_auth_output]: {
        apiVersion: 'keda.sh/v1alpha1',
        kind: 'TriggerAuthentication',
        metadata: {
          name: name,
          namespace: namespace_name,
        },
        spec: {
          secretTargetRef: [
            {
              parameter: 'password',
              name: app_name + '-kafka-user',
              key: 'password',
            },
          ],
        },
      },
    },
}
