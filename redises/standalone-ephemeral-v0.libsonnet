local servicemonitor_v0 = import '../servicemonitors/v0.libsonnet';

{
  resources(
    account_number,
    region,
    cluster,
    environment,
    namespace_name,
    resource_name,
    requested_resources,
    config,
  )::

    local fmt_context = {
      account_number: account_number,
      region: region,
      cluster: cluster,
      environment: environment,
      namespace_name: namespace_name,
      resource_name: resource_name,
    };

    local redis_output = '%(resource_name)s-redis.json' % fmt_context;

    local config_output = '%(resource_name)s-redis-config.json' % fmt_context;
    local config_name = '%(resource_name)s-config' % fmt_context;

    local ingress_output = '%(resource_name)s-redis-ingress.json' % fmt_context;
    local servicemonitor_output = '%(resource_name)s-servicemonitor.json' % fmt_context;

    {
      [redis_output]: {
        apiVersion: 'redis.redis.opstreelabs.in/v1beta2',
        kind: 'Redis',
        metadata: {
          name: resource_name,
          namespace: namespace_name,
        },
        spec: {
          podSecurityContext: {
            runAsUser: 1000,
            fsGroup: 1000,
          },
          kubernetesConfig: {
            image: 'quay.io/opstree/redis:v7.2.3',
            imagePullPolicy: 'IfNotPresent',
            resources: requested_resources,
          },
          redisConfig: {
            additionalRedisConfig: config_name,
          },
          redisExporter: {
            enabled: true,
            image: 'quay.io/opstree/redis-exporter:v1.44.0',
            imagePullPolicy: 'IfNotPresent',
            //            resources: requested_resources,
          },
          readinessProbe: {
            failureThreshold: 5,
            initialDelaySeconds: 15,
            periodSeconds: 15,
            successThreshold: 1,
            timeoutSeconds: 5,
          },
          livenessProbe: {
            failureThreshold: 5,
            initialDelaySeconds: 15,
            periodSeconds: 15,
            successThreshold: 1,
            timeoutSeconds: 5,
          },
          //          affinity: {
          //            nodeAffinity: {
          //              requiredDuringSchedulingIgnoredDuringExecution: {
          //                nodeSelectorTerms: [
          //                  {
          //                    matchExpressions: [
          //                      {
          //                        key: 'cloud',
          //                        operator: 'NotIn',
          //                        values: [
          //                          'azure',
          //                        ],
          //                      },
          //                    ],
          //                  },
          //                ],
          //              },
          //            },
          //          },
        },
      },
      [servicemonitor_output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: resource_name,
          labels: {
            app: resource_name,
          },
          namespace: namespace_name,
        },
        spec: {
          selector: {
            matchLabels: {
              app: resource_name,
            },
          },
          endpoints: [
            {
              targetPort: 9121,
              interval: '30s',
              scrapeTimeout: '10s',
              path: '/metrics',
            },
          ],
          namespaceSelector: {
            matchNames: [
              namespace_name,
            ],
          },
        },
      },
      [config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: config_name,
          namespace: namespace_name,
        },
        data: {
          'redis-additional.conf': config,
        },
      },
    },
}
