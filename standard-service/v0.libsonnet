local imagerepos = import '../imagerepositories/v0.libsonnet';
local serviceaccounts = import '../serviceaccounts/v0.libsonnet';

{
  resources(
    aws_account_number,
    region,
    cluster,
    environment,
    namespace_name,
    app,
    command,
    image_prefix,
    service_account_name,
    ports,
    env,
    envFrom,
    hostname,
    dns_target,
    ingress_class,
    resources,
    replicas,
    flux,
  )::
    local app_name = if command == '' then app else app + '-' + command;
    local fmt_context = {
      app: app,
      command: command,
      app_name: app_name,
      cluster: cluster,
      environment: environment,
      namespace_name: namespace_name,
      image_prefix: image_prefix,
    };

    local run_command = if command == '' then [
      '/app/%(app_name)s' % fmt_context,
      'server',
    ] else [
      '/app/%(app_name)s' % fmt_context,
      command,
    ];

    local image_repo_name = if command == '' then '%(app)s' % fmt_context else '%(app)s-%(command)s' % fmt_context;
    local image = image_prefix + '/' + image_repo_name + ':latest';
    local deployment_output = '%(app_name)s-deployment.json' % fmt_context;

    local service_account = serviceaccounts.resources(
      service_account_name,
      namespace_name,
      aws_account_number,
      service_account_name,
    );

    local service_output = '%(app_name)s-service.json' % fmt_context;
    local ingress_output = '%(app_name)s-ingress.json' % fmt_context;
    local servicemonitor_output = '%(app_name)s-servicemonitor.json' % fmt_context;

    local imagerepository = if flux then imagerepos.resources(
      name=app_name,
      namespace=namespace_name,
      aws_account_number=aws_account_number,
      aws_region=region,
      interval='1m0s',
    ) else {};


    {
      [deployment_output]: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: app_name,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        spec: {
          replicas: replicas,
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
              serviceAccountName: service_account_name,
              containers: [
                {
                  name: app_name,
                  image: image,
                  imagePullPolicy: 'IfNotPresent',
                  command: run_command,
                  ports: ports,
                  resources: resources,
                  env: env,
                  envFrom: envFrom,
                  readinessProbe: {
                    failureThreshold: 5,
                    httpGet: {
                      path: '/readyz',
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
      [service_output]: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: app_name,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        spec: {
          ports: ports,
          selector: {
            app: app_name,
          },
          sessionAffinity: 'None',
          type: 'ClusterIP',
        },
      },
      [servicemonitor_output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: app_name,
          labels: {
            app: app_name,
          },
          namespace: namespace_name,
        },
        spec: {
          selector: {
            matchLabels: {
              app: app_name,
            },
          },
          endpoints: [
            {
              port: 'metrics',
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
            'nginx.ingress.kubernetes.io/modsecurity-snippet': |||
              SecRuleEngine On
              # Exclude OAuth scope parameter from LFI rule 930120 - false positive on userinfo.profile
              SecRuleUpdateTargetById 930120 "!ARGS:scope"
            |||,
            // 'nginx.ingress.kubernetes.io/enable-cors': 'true',
            // 'nginx.ingress.kubernetes.io/cors-allow-origin': '*',
            // 'nginx.ingress.kubernetes.io/cors-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
            // 'nginx.ingress.kubernetes.io/cors-allow-headers': 'DNT,X-CustomHeader,X-LANG,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,X-Api-Key,X-Device-Id,Access-Control-Allow-Origin,Authorization',
          },
        },
        spec: {
          ingressClassName: ingress_class,
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
                          number: 9999,
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
    + service_account
    + imagerepository,
}
