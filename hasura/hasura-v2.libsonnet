local servicemonitors_v1 = import '../servicemonitors/v1.libsonnet';
local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';

{
  resources(
    name,
    aws_account_number,
    region,
    cluster,
    environment,
    namespace_name,
    minReplicas,
    maxReplicas,
    cpuUtilization,
    hostname_int,
    hostname_ext,
    hostname_admin,
    dns_target_int,
    dns_target_ext,
    resources,
    istio,
  )::
    local app_name = name;
    local fmt_context = {
      app_name: app_name,
      cluster: cluster,
      environment: environment,
      namespace_name: namespace_name,
      istio: istio,
    };

    local deployment_output = '%(app_name)s-deployment.json' % fmt_context;
    local service_output = '%(app_name)s-service.json' % fmt_context;
    local scaled_object_output = '%(app_name)s-scaled-object.json' % fmt_context;
    local ingress_output_int = '%(app_name)s-ingress-int.json' % fmt_context;
    local ingress_output_ext = '%(app_name)s-ingress-ext.json' % fmt_context;

    local admin_app_name = '%(app_name)s-admin' % fmt_context;
    local admin_deployment_output = '%(app_name)s-admin-deployment.json' % fmt_context;
    local admin_service_output = '%(app_name)s-admin-service.json' % fmt_context;
    local admin_scaled_object_output = '%(app_name)s-admin-scaled-object.json' % fmt_context;
    local admin_ingress_output = '%(app_name)s-admin-ingress.json' % fmt_context;

    local service_account = serviceaccounts_v0.resources(
      name=app_name,
      namespace=namespace_name,
      aws_account_number=aws_account_number,
      iam_role_name=app_name,
    );

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
        name: app_name,
        key: 'HASURA_GRAPHQL_METRICS_SECRET',
      },
    );


    local redis_name = '%(app_name)s-redis-standalone' % fmt_context;
    local redis_output = '%(app_name)s-redis.json' % fmt_context;
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
      [ingress_output_int]: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: app_name + '-int',
          namespace: namespace_name,
          annotations: {
            'cert-manager.io/cluster-issuer': 'letsencrypt',
            'external-dns.alpha.kubernetes.io/hostname': hostname_int,
            'external-dns.alpha.kubernetes.io/target': dns_target_int,
            'external-dns.alpha.kubernetes.io/ttl': '60',
            //            'nginx.ingress.kubernetes.io/limit-connections': '100',
            //            'nginx.ingress.kubernetes.io/limit-rps': '100',
          },
        },
        spec: {
          ingressClassName: 'nginx-ext',
          tls: [
            {
              hosts: [
                hostname_int,
              ],
              secretName: app_name + '-int-cert',
            },
          ],
          rules: [
            {
              host: hostname_int,
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
      [ingress_output_ext]: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: app_name + '-ext',
          namespace: namespace_name,
          annotations: {
            'cert-manager.io/cluster-issuer': 'letsencrypt',
            'external-dns.alpha.kubernetes.io/hostname': hostname_ext,
            'external-dns.alpha.kubernetes.io/target': dns_target_ext,
            'external-dns.alpha.kubernetes.io/ttl': '60',
            //            'nginx.ingress.kubernetes.io/limit-connections': '100',
            //            'nginx.ingress.kubernetes.io/limit-rps': '100',
            'nginx.ingress.kubernetes.io/enable-cors': 'true',
            'nginx.ingress.kubernetes.io/cors-allow-origin': '*',
            'nginx.ingress.kubernetes.io/cors-allow-methods': 'GET, POST, OPTIONS',
            'nginx.ingress.kubernetes.io/cors-allow-headers': 'DNT,X-CustomHeader,X-LANG,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,X-Api-Key,X-Device-Id,Access-Control-Allow-Origin,Authorization',
          },
        },
        spec: {
          ingressClassName: 'nginx-ext',
          tls: [
            {
              hosts: [
                hostname_ext,
              ],
              secretName: app_name + '-ext-cert',
            },
          ],
          rules: [
            {
              host: hostname_ext,
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
            'external-dns.alpha.kubernetes.io/hostname': hostname_admin,
            'external-dns.alpha.kubernetes.io/target': dns_target_int,
            'external-dns.alpha.kubernetes.io/ttl': '60',
          },
        },
        spec: {
          ingressClassName: 'nginx',
          tls: [
            {
              hosts: [
                hostname_admin,
              ],
              secretName: admin_app_name + '-cert',
            },
          ],
          rules: [
            {
              host: hostname_admin,
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
          //          redisConfig: {
          //            additionalRedisConfig: redis_config_name,
          //          },
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
      //      [redis_config_output]: {
      //        apiVersion : 'v1',
      //        kind : 'ConfigMap',
      //        metadata : {
      //          name : redis_config_name,
      //          namespace : namespace_name,
      //        },
      //        data : {
      //          'redis-external.conf' : 'appendonly no\n',
      //        },
      //      },
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
    }
    + service_account
    + servicemonitor,
}
