local servicemonitors = import '../servicemonitors/v3.libsonnet';

{
  resources(
    app_name,
    namespace_name,
    aws_region,
    users,
    buckets,
    config_secret_name,
    image,
    servers,
    volumes_per_server,
    tolerations,
    affinity,
    storage,
    storage_class,
    hostname,
    console_hostname,
    dns_target,
  )::
    local fmt_context = {
      app_name: app_name,

    };

    local minio_tenant_output = '%(app_name)s-tenant.json' % fmt_context;
    local ingress_output = '%(app_name)s-ingress.json' % fmt_context;
    local ingress_console_output = '%(app_name)s-ingress-console.json' % fmt_context;

    local servicemonitor = servicemonitors.resources(
      name=app_name,
      namespace=namespace_name,
      labels={
        app: app_name,
      },
      match_labels={
        app: app_name,
      },
      path='/minio/v2/metrics/cluster',
      port='80',
      interval='30s',
      timeout='10s',
    );

    {
      [minio_tenant_output]: {
        apiVersion: 'minio.min.io/v2',
        kind: 'Tenant',
        metadata: {
          name: app_name,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        spec: {
          users: users,
          //        env: [
          //
          //        ],
          buckets: buckets,
          podManagementPolicy: 'Parallel',
          configuration: {
            name: config_secret_name,
          },
          image: image,
          mountPath: '/export',
          serviceMetadata: {
            minioServiceLabels: {
              app: app_name,
            },
            consoleServiceLabels: {
              app: app_name,
            },
          },
          pools: [
            {
              servers: servers,
              name: app_name + '-0',
              volumesPerServer: volumes_per_server,
              tolerations: tolerations,
              affinity: affinity,
              volumeClaimTemplate: {
                apiVersion: 'v1',
                kind: 'persistentvolumeclaims',
                spec: {
                  accessModes: [
                    'ReadWriteOnce',
                  ],
                  resources: {
                    requests: {
                      storage: storage,
                    },
                  },
                  storageClassName: storage_class,
                },
              },
              securityContext: {
                runAsUser: 1000,
                runAsGroup: 1000,
                runAsNonRoot: true,
                fsGroup: 1000,
                fsGroupChangePolicy: 'OnRootMismatch',
              },
              containerSecurityContext: {
                runAsUser: 1000,
                runAsGroup: 1000,
                runAsNonRoot: true,
                allowPrivilegeEscalation: false,
                capabilities: {
                  drop: [
                    'ALL',
                  ],
                },
                seccompProfile: {
                  type: 'RuntimeDefault',
                },
              },
            },
          ],
          requestAutoCert: false,
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
            'external-dns.alpha.kubernetes.io/hostname': hostname,
            'external-dns.alpha.kubernetes.io/target': dns_target,
            'external-dns.alpha.kubernetes.io/ttl': '60',
          },
        },
        spec: {
          ingressClassName: 'nginx',
          tls: [
            {
              hosts: [
                hostname,
                '*.' + hostname,
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
                        name: 'minio',  // The operator fails to create a service with the name of the tenant.  It does create a headless service.  Unclear whether that's useful to us however.
                        port: {
                          number: 80,
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
      [ingress_console_output]: {
        apiVersion: 'networking.k8s.io/v1',
        kind: 'Ingress',
        metadata: {
          name: app_name + '-console',
          namespace: namespace_name,
          annotations: {
            'cert-manager.io/cluster-issuer': 'letsencrypt',
            'external-dns.alpha.kubernetes.io/hostname': hostname,
            'external-dns.alpha.kubernetes.io/target': dns_target,
            'external-dns.alpha.kubernetes.io/ttl': '60',
          },
        },
        spec: {
          ingressClassName: 'nginx',
          tls: [
            {
              hosts: [
                console_hostname,
              ],
              secretName: app_name + '-console-cert',
            },
          ],
          rules: [
            {
              host: console_hostname,
              http: {
                paths: [
                  {
                    path: '/',
                    pathType: 'Prefix',
                    backend: {
                      service: {
                        name: app_name + '-console',
                        port: {
                          number: 9090,
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
    }
    + servicemonitor,
}
