local servicemonitor_v0 = import '../servicemonitors/v0.libsonnet';

{
  resources(
    account_number,
    region,
    cluster,
    environment,
    namespace_name,
    resource_name,
  )::

    local fmt_context = {
      account_number: account_number,
      region: region,
      cluster: cluster,
      environment: environment,
      namespace_name: namespace_name,
      resource_name: resource_name,
    };

    local sentinel_output = '%(resource_name)s-sentinel.json' % fmt_context;

    {
      [sentinel_output]: {
        apiVersion: 'redis.redis.opstreelabs.in/v1beta2',
        kind: 'RedisSentinel',
        metadata: {
          name: resource_name,
          namespace: namespace_name,
        },
        spec: {
          clusterSize: 3,
          podSecurityContext: {
            fsGroup: 1000,
            runAsUser: 1000,
          },
          redisSentinelConfig: {
            redisReplicationName: resource_name,
          },
          kubernetesConfig: {
            image: 'quay.io/opstree/redis-sentinel:v7.2.6',
            imagePullPolicy: 'IfNotPresent',
            resources: {
              requests: {
                cpu: '101m',
                memory: '128Mi',
              },
              limits: {
                cpu: '101m',
                memory: '128Mi',
              },
            },
          },
        },
      },
    },
}
