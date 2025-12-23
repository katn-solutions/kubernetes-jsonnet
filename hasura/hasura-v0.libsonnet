local servicemonitors_v1 = import '../servicemonitors/v1.libsonnet';
local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';
local vaults_v0 = import '../vaults/v0.libsonnet';

local app_name = 'hasura';
//local clickhouse_connector_name = 'hasura-clickhouse-connector';
//local clickhouse_connector_deployment_output = clickhouse_connector_name + '-deployment.json';
//local clickhouse_connector_autoscaler_output = clickhouse_connector_name + '-hpa.json';
//local clickhouse_connector_service_output = clickhouse_connector_name + '-service.json';
//local clickhouse_connector_service_name = 'data-connector-agent';

{
  resources(
    aws_account_number,
    region,
    cluster,
    environment,
    namespace_name,
    ingress_class,
    minReplicas,
    maxReplicas,
    cpuUtilization,
    hostname,
    admin_hostname,
    resources,
    istio,
  )::
    local fmt_context = {
      app_name: app_name,
      cluster: cluster,
      environment: environment,
      namespace_name: namespace_name,
      ingress_class: ingress_class,
      istio: istio,
    };

    local deployment_output = '%(app_name)s-deployment.json' % fmt_context;
    local service_output = '%(app_name)s-service.json' % fmt_context;
    local scaled_object_output = '%(app_name)s-scaled-object.json' % fmt_context;
    local ingress_output = '%(app_name)s-ingress.json' % fmt_context;

    local admin_app_name = '%(app_name)s-admin' % fmt_context;
    local admin_deployment_output = '%(app_name)s-admin-deployment.json' % fmt_context;
    local admin_service_output = '%(app_name)s-admin-service.json' % fmt_context;
    local admin_scaled_object_output = '%(app_name)s-admin-scaled-object.json' % fmt_context;
    local admin_ingress_output = '%(app_name)s-admin-ingress.json' % fmt_context;

    local service_account = serviceaccounts_v0.resources(app_name, namespace_name, aws_account_number, app_name);

    local secret_mount = environment;
    local secret_path = app_name;
    local secret_refresh = '30s';
    local secret_name = app_name;
    local vault_auth = vaults_v0.auth_resources(
      app_name,
      namespace_name,
      cluster,
      app_name,
      app_name
    );

    local vault_secret = vaults_v0.secret_resources(
      app_name,
      namespace_name,
      cluster,
      app_name,
      secret_mount,
      secret_path,
      secret_name,
      secret_refresh,
    );

    local admin_secret_path = admin_app_name;
    local admin_secret_name = admin_app_name;

    local admin_vault_auth = vaults_v0.auth_resources(
      admin_app_name,
      namespace_name,
      cluster,
      app_name,
      app_name
    );

    local admin_vault_secret = vaults_v0.secret_resources(
      admin_app_name,
      namespace_name,
      cluster,
      admin_app_name,
      secret_mount,
      admin_secret_path,
      admin_secret_name,
      secret_refresh,
    );

    local kafka_user_output = '%(app_name)s-hasura-kafka-%(namespace_name)s-user.json' % fmt_context;

    local servicemonitor = servicemonitors_v1.resources(
      app_name,
      namespace_name,
      {
        app: app_name,
      },
      {
        app: app_name,
      },
      '/v1/metrics',
      {
        name: 'hasura',
        key: 'HASURA_GRAPHQL_METRICS_SECRET',
      },
    );


    local redis_name = '%(app_name)s-redis-standalone' % fmt_context;
    local redis_output = '%(app_name)s-redis.json' % fmt_context;
    local redis_config_name = '%(app_name)s-redis' % fmt_context;
    local redis_config_output = '%(app_name)s-redis-config.json' % fmt_context;
    local redis_service_monitor_output = '%(app_name)s-redis-service-monitor.json' % fmt_context;

    {
      [deployment_output]: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          selector: {
            matchLabels: {
              app: app_name,
            },
          },
          strategy: {
            rollingUpdate: {
              maxSurge: 1,
              maxUnavailable: 1,
            },
            type: 'RollingUpdate',
          },
          template: {
            metadata: {
              labels: {
                app: app_name,
              },
            },
            spec: {
              serviceAccountName: app_name,
              containers: [
                {
                  name: app_name,
                  image: 'hasura/graphql-engine:v2.39.2',
                  imagePullPolicy: 'IfNotPresent',
                  ports: [
                    {
                      name: 'http',
                      containerPort: 8080,
                      protocol: 'TCP',
                    },
                  ],
                  resources: resources,
                  envFrom: [
                    {
                      secretRef: {
                        name: app_name,
                      },
                    },
                  ],
                  readinessProbe: {
                    failureThreshold: 5,
                    httpGet: {
                      path: '/healthz',
                      port: 8080,
                    },
                    initialDelaySeconds: 10,
                    periodSeconds: 10,
                    successThreshold: 1,
                    timeoutSeconds: 5,
                  },
                  livenessProbe: {
                    failureThreshold: 5,
                    httpGet: {
                      path: '/healthz',
                      port: 8080,
                    },
                    initialDelaySeconds: 30,
                    periodSeconds: 10,
                    successThreshold: 1,
                    timeoutSeconds: 5,
                  },
                },
              ],
            },
          },
        },
      },
      [scaled_object_output]: {
        apiVersion: 'keda.sh/v1alpha1',
        kind: 'ScaledObject',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          scaleTargetRef: {
            apiVersion: 'apps/v1',
            kind: 'Deployment',
            name: app_name,
          },
          minReplicaCount: minReplicas,
          maxReplicaCount: maxReplicas,
          triggers: [
            {
              type: 'cpu',
              metricType: 'Utilization',
              metadata: {
                value: '85',
                containerName: app_name,
              },
            },
            {
              type: 'memory',
              metricType: 'Utilization',
              metadata: {
                value: '85',
                containerName: app_name,
              },
            },
          ],
        },
      },
      //      [autoscaler_output]: {
      //        apiVersion: 'autoscaling/v2',
      //        kind: 'HorizontalPodAutoscaler',
      //        metadata: {
      //          name: app_name,
      //          namespace: namespace_name,
      //        },
      //        spec: {
      //          scaleTargetRef: {
      //            apiVersion: 'apps/v1',
      //            kind: 'Deployment',
      //            name: app_name,
      //          },
      //          minReplicas: minReplicas,
      //          maxReplicas: maxReplicas,
      //          metrics: [{
      //            type: 'Resource',
      //            resource: {
      //              name: 'cpu',
      //              target: {
      //                type: 'Utilization',
      //                averageUtilization: 85,
      //              },
      //            },
      //          }],
      //        },
      //      },
      [service_output]: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          ports: [
            {
              name: 'http',
              port: 8080,
              protocol: 'TCP',
              targetPort: 8080,
            },
          ],
          selector: {
            app: app_name,
          },
          sessionAffinity: 'None',
          type: 'ClusterIP',
        },
      },
      [ingress_output]: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: app_name,
          namespace: namespace_name,
          annotations: {
            'cert-manager.io/cluster-issuer': 'letsencrypt',
            //            'nginx.ingress.kubernetes.io/limit-connections': '100',
            //            'nginx.ingress.kubernetes.io/limit-rps': '100',
          },
        },
        spec: {
          ingressClassName: 'nginx-ext',
          tls: [
            {
              hosts: [
                hostname,
              ],
              secretName: app_name + '-cert',
            },
          ],
          rules: [
            {
              host: hostname,
              http: {
                paths: [
                  {
                    path: '/',
                    pathType: 'Prefix',
                    backend: {
                      service: {
                        name: app_name,
                        port: {
                          number: 8080,
                        },
                      },
                    },
                  },
                ],
              },
            },
          ],
        },
      },
      [admin_deployment_output]: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: admin_app_name,
          namespace: namespace_name,
        },
        spec: {
          selector: {
            matchLabels: {
              app: admin_app_name,
            },
          },
          strategy: {
            rollingUpdate: {
              maxSurge: 1,
              maxUnavailable: 1,
            },
            type: 'RollingUpdate',
          },
          template: {
            metadata: {
              labels: {
                app: admin_app_name,
              },
            },
            spec: {
              serviceAccountName: app_name,
              containers: [
                {
                  name: admin_app_name,
                  image: 'hasura/graphql-engine:v2.39.2',
                  imagePullPolicy: 'IfNotPresent',
                  ports: [
                    {
                      name: 'http',
                      containerPort: 8080,
                      protocol: 'TCP',
                    },
                  ],
                  resources: {
                    limits: {
                      cpu: '1000m',
                      memory: '2Gi',
                    },
                    requests: {
                      cpu: '500m',
                      memory: '512Mi',
                    },
                  },
                  envFrom: [
                    {
                      secretRef: {
                        name: admin_app_name,
                      },
                    },
                  ],
                  readinessProbe: {
                    failureThreshold: 5,
                    httpGet: {
                      path: '/healthz',
                      port: 8080,
                    },
                    initialDelaySeconds: 10,
                    periodSeconds: 10,
                    successThreshold: 1,
                    timeoutSeconds: 5,
                  },
                  livenessProbe: {
                    failureThreshold: 5,
                    httpGet: {
                      path: '/healthz',
                      port: 8080,
                    },
                    initialDelaySeconds: 30,
                    periodSeconds: 10,
                    successThreshold: 1,
                    timeoutSeconds: 5,
                  },
                },
              ],
            },
          },
        },
      },
      [admin_scaled_object_output]: {
        apiVersion: 'keda.sh/v1alpha1',
        kind: 'ScaledObject',
        metadata: {
          name: admin_app_name,
          namespace: namespace_name,
        },
        spec: {
          scaleTargetRef: {
            apiVersion: 'apps/v1',
            kind: 'Deployment',
            name: admin_app_name,
          },
          minReplicaCount: minReplicas,
          maxReplicaCount: maxReplicas,
          triggers: [
            {
              type: 'cpu',
              metricType: 'Utilization',
              metadata: {
                value: '85',
                containerName: admin_app_name,
              },
            },
            {
              type: 'memory',
              metricType: 'Utilization',
              metadata: {
                value: '85',
                containerName: admin_app_name,
              },
            },
          ],
        },
      },
      //      [admin_autoscaler_output]: {
      //        apiVersion: 'autoscaling/v2',
      //        kind: 'HorizontalPodAutoscaler',
      //        metadata: {
      //          name: admin_app_name,
      //          namespace: namespace_name,
      //        },
      //        spec: {
      //          scaleTargetRef: {
      //            apiVersion: 'apps/v1',
      //            kind: 'Deployment',
      //            name: admin_app_name,
      //          },
      //          minReplicas: 1,
      //          maxReplicas: 3,
      //          metrics: [{
      //            type: 'Resource',
      //            resource: {
      //              name: 'cpu',
      //              target: {
      //                type: 'Utilization',
      //                averageUtilization: 85,
      //              },
      //            },
      //          }],
      //        },
      //      },
      [admin_service_output]: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: admin_app_name,
          namespace: namespace_name,
        },
        spec: {
          ports: [
            {
              name: 'http',
              port: 8080,
              protocol: 'TCP',
              targetPort: 8080,
            },
          ],
          selector: {
            app: admin_app_name,
          },
          sessionAffinity: 'None',
          type: 'ClusterIP',
        },
      },
      [admin_ingress_output]: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: admin_app_name,
          namespace: namespace_name,
          annotations: {
            'cert-manager.io/cluster-issuer': 'letsencrypt',
          },
        },
        spec: {
          ingressClassName: 'nginx',
          tls: [
            {
              hosts: [
                admin_hostname,
              ],
              secretName: admin_app_name + '-cert',
            },
          ],
          rules: [
            {
              host: admin_hostname,
              http: {
                paths: [
                  {
                    path: '/',
                    pathType: 'Prefix',
                    backend: {
                      service: {
                        name: admin_app_name,
                        port: {
                          number: 8080,
                        },
                      },
                    },
                  },
                ],
              },
            },
          ],
        },
      },
      [redis_output]: {
        apiVersion: 'redis.redis.opstreelabs.in/v1beta1',
        kind: 'Redis',
        metadata: {
          name: redis_name,
          namespace: namespace_name,
        },
        spec: {
          kubernetesConfig: {
            image: 'quay.io/opstree/redis:6.2.5',
            imagePullPolicy: 'IfNotPresent',
            resources: {
              limits: {
                cpu: '200m',
                memory: '2000Mi',
              },
              requests: {
                cpu: '100m',
                memory: '1256Mi',
              },
            },
          },
          redisConfig: {
            additionalRedisConfig: redis_config_name,
          },
          redisExporter: {
            enabled: true,
            image: 'quay.io/opstree/redis-exporter:1.0',
            imagePullPolicy: 'IfNotPresent',
            resources: {
              limits: {
                cpu: '100m',
                memory: '128Mi',
              },
              requests: {
                cpu: '100m',
                memory: '128Mi',
              },
            },
          },
        },
      },
      [redis_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: redis_config_name,
          namespace: namespace_name,
        },
        data: {
          'redis-external.conf': 'appendonly no\n',
        },
      },
      [redis_service_monitor_output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: redis_name,
          namespace: namespace_name,
          labels: {
            app: redis_name,
            'redis-operator': 'true',
          },
        },
        spec: {
          endpoints: [
            {
              interval: '30s',
              port: 'redis-exporter',
              scrapeTimeout: '10s',
            },
          ],
          namespaceSelector: {
            matchNames: [
              namespace_name,
            ],
          },
          selector: {
            matchLabels: {
              'redis-setup_type': 'standalone',
            },
          },
        },
      },
      //      [clickhouse_connector_deployment_output]: {
      //        apiVersion: 'apps/v1',
      //        kind: 'Deployment',
      //        metadata: {
      //          name: clickhouse_connector_name,
      //          namespace: namespace_name,
      //        },
      //        spec: {
      //          selector: {
      //            matchLabels: {
      //              app: clickhouse_connector_name,
      //            },
      //          },
      //          strategy: {
      //            rollingUpdate: {
      //              maxSurge: 1,
      //              maxUnavailable: 1,
      //            },
      //            type: 'RollingUpdate',
      //          },
      //          template: {
      //            metadata: {
      //              labels: {
      //                app: clickhouse_connector_name,
      //              },
      //            },
      //            spec: {
      //              serviceAccountName: app_name,
      //              containers: [
      //                {
      //                  name: 'connector',
      //                  image: 'hasura/clickhouse-data-connector:v2.40.0',
      //                  ports: [
      //                    {
      //                      name: 'http',
      //                      containerPort: 8080,
      //                      protocol: 'TCP',
      //                    },
      //                  ],
      //                  //                  livenessProbe: {
      //                  //                    exec: {
      //                  //                      command: [
      //                  //                        'rm',
      //                  //                        '/tmp/healthy',
      //                  //                      ],
      //                  //                    },
      //                  //                    failureThreshold: 10,
      //                  //                    initialDelaySeconds: 30,
      //                  //                    periodSeconds: 300,
      //                  //                    terminationGracePeriodSeconds: 60,
      //                  //                    timeoutSeconds: 300,
      //                  //                  },
      //                },
      //              ],
      //            },
      //          },
      //        },
      //      },
      //      [clickhouse_connector_service_output]: {
      //        apiVersion: 'v1',
      //        kind: 'Service',
      //        metadata: {
      //          name: clickhouse_connector_service_name,
      //          namespace: namespace_name,
      //        },
      //        spec: {
      //          ports: [
      //            {
      //              name: 'http',
      //              port: 8080,
      //              protocol: 'TCP',
      //              targetPort: 8080,
      //            },
      //          ],
      //          selector: {
      //            app: clickhouse_connector_name,
      //          },
      //          sessionAffinity: 'None',
      //          type: 'ClusterIP',
      //        },
      //      },
      //      [clickhouse_connector_autoscaler_output]: {
      //        apiVersion: 'autoscaling/v2',
      //        kind: 'HorizontalPodAutoscaler',
      //        metadata: {
      //          name: clickhouse_connector_name,
      //          namespace: namespace_name,
      //        },
      //        spec: {
      //          scaleTargetRef: {
      //            apiVersion: 'apps/v1',
      //            kind: 'Deployment',
      //            name: clickhouse_connector_name,
      //          },
      //          minReplicas: minReplicas,
      //          maxReplicas: maxReplicas,
      //          metrics: [{
      //            type: 'Resource',
      //            resource: {
      //              name: 'cpu',
      //              target: {
      //                type: 'Utilization',
      //                averageUtilization: 85,
      //              },
      //            },
      //          }],
      //        },
      //      },
      [kafka_user_output]: {
        apiVersion: 'kafka.strimzi.io/v1beta2',
        kind: 'KafkaUser',
        metadata: {
          name: app_name + '-kafka-user',
          namespace: namespace_name,
          labels: {
            'strimzi.io/cluster': namespace_name,
          },
        },
        spec: {
          authentication: {
            type: 'scram-sha-512',
          },
          authorization: {
            type: 'simple',
            acls: [
              {
                resource: {
                  type: 'topic',
                  name: 'points-event-v0',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                ],
                host: '*',
              },
              {
                resource: {
                  type: 'topic',
                  name: 'send-email-v3',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                  'Read',
                  'Write',
                ],
                host: '*',
              },
              {
                resource: {
                  type: 'topic',
                  name: 'wallet-created-v2',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                  'Write',
                ],
                host: '*',
              },
              {
                resource: {
                  type: 'topic',
                  name: 'fill-closed-v0',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                  'Write',
                ],
                host: '*',
              },
              {
                resource: {
                  type: 'topic',
                  name: 'vienna-tx-detected-v2',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                  'Write',
                ],
                host: '*',
              },
              {
                resource: {
                  type: 'topic',
                  name: 'points-event-v0',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                  'Read',
                ],
                host: '*',
              },
              {
                resource: {
                  type: 'topic',
                  name: 'wallet-created-v2',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                  'Write',
                ],
                host: '*',
              },
              {
                resource: {
                  type: 'group',
                  name: 'user-service',
                  patternType: 'literal',
                },
                operations: [
                  'Create',
                  'Describe',
                  'Read',
                ],
                host: '*',
              },
            ],
          },
        },
      },
    }
    + service_account
    + vault_auth
    + vault_secret
    + admin_vault_auth
    + admin_vault_secret
    + servicemonitor,
}
