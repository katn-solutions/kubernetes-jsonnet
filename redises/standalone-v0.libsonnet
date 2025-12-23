{
  resources(
    account_number,
    region,
    cluster,
    environment,
    namespace_name,
    resource_name,
    storage,
    requested_resources,
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
    local config_name = '%(resource_name)s-redis-config' % fmt_context;

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
          storage: {
            keepAfterDelete: true,
            volumeClaimTemplate: {
              spec: {
                accessModes: [
                  'ReadWriteOnce',
                ],
                resources: {
                  requests: {
                    storage: storage,
                  },
                },
              },
            },
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
          'redis-external.conf': 'appendonly no\n',
        },
      },
      //      [ingress_output]: {
      //        apiVersion: 'networking.k8s.io/v1',
      //        kind: 'Ingress',
      //        metadata: {
      //          name: resource_name,
      //          namespace: namespace_name,
      //          annotations: {
      //            'cert-manager.io/cluster-issuer': 'letsencrypt',
      //            },
      //        },
      //        spec: {
      //          ingressClassName: 'nginx',
      //          tls: [
      //            {
      //              hosts: [domain_name],
      //              secretName: resource_name + '-cert',
      //            },
      //          ],
      //          rules: [
      //            {
      //              host: domain_name,
      //              http: {
      //                paths: [
      //                  {
      //                    pathType: 'Prefix',
      //                    path: '/',
      //                    backend: {
      //                      service: {
      //                        name: 'redis',
      //                        port: {
      //                          number: 6479,
      //                        },
      //                      },
      //                    },
      //                  },
      //                ],
      //              },
      //            },
      //          ],
      //        },
      //      },
    },
}
