local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';
local servicemonitors_v0 = import '../servicemonitors/v0.libsonnet';
local vaults_v0 = import '../vaults/v0.libsonnet';

local app_name = 'postgres-exporter';
local port = 9187;

{
  app_name: app_name,
  resources(
    account_number,
    region,
    cluster,
    environment,
    namespace_name,
  )::
    local fmt_context = {
      app_name: app_name,
      cluster: cluster,
      environment: environment,
      namespace: namespace_name,
      account_number: account_number,
    };

    local service_name = '%(app_name)s' % fmt_context;

    local namespaced_name = '%(app_name)s-%(namespace)s' % fmt_context;
    local deployment_output = '%(app_name)s-deployment.json' % fmt_context;
    local service_output = '%(app_name)s-service.json' % fmt_context;

    local prometheus_rule_output = '%(app_name)s-service-prometheusRule.json' % fmt_context;
    local prometheus_rule_expression = 'absent(kube_pod_container_info{namespace="%(namespace)s",pod=~"%(app_name)s.+" })' % fmt_context;
    local prometheus_duration = '5m';
    local prometheus_severity = 'critical';
    local prometheus_alert = '%(app_name)s Down (%(cluster)s)' % fmt_context;
    local prometheus_message = '%(app_name)s is not running!' % fmt_context;

    local service_account = serviceaccounts_v0.resources(app_name, namespace_name, account_number, namespaced_name);

    local secret_mount = environment;
    local secret_path = app_name;
    local secret_refresh = '30s';
    local secret_name = app_name;

    local postgres_exporter_config_output = 'postgres-exporter-config.json';

    local vault_auth = vaults_v0.auth_resources(
      app_name,  // name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // role
      app_name  // serviceaccount
    );

    local vault_secret = vaults_v0.secret_resources(
      app_name,
      namespace_name,
      cluster,
      app_name,
      secret_mount,
      secret_path,
      secret_name,
      secret_refresh
    );

    local servicemonitor = servicemonitors_v0.resources(
      app_name,
      namespace_name,
      {
        app: app_name,
      },
      {
        app: app_name,
      },
    );


    {
      [deployment_output]: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          replicas: 1,
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
                  name: 'exporter',
                  image: 'wrouesnel/postgres_exporter:v0.8.0',
                  args: ['--extend.query-path=/etc/postgres_exporter/queries.yaml'],
                  ports: [
                    {
                      name: 'http',
                      containerPort: port,
                    },
                  ],
                  env: [
                    {
                      name: 'DATA_SOURCE_NAME',
                      valueFrom: {
                        secretKeyRef: {
                          key: 'POSTGRES_DSN',
                          name: app_name,
                        },
                      },
                    },
                  ],
                  volumeMounts: [
                    {
                      name: 'exporter-config',
                      mountPath: '/etc/postgres_exporter',
                    },
                  ],
                },
              ],
              volumes: [
                {
                  name: 'exporter-config',
                  configMap: {
                    name: 'postgres-exporter-config',
                  },
                },
              ],
            },
          },
        },
      },
      [prometheus_rule_output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: app_name,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        spec: {
          groups: [
            {
              name: app_name,
              rules: [
                {
                  alert: prometheus_alert,
                  annotations: {
                    message: prometheus_message,
                  },
                  expr: prometheus_rule_expression,
                  'for': prometheus_duration,
                  labels: {
                    app: app_name,
                    severity: prometheus_severity,
                  },
                },
              ],
            },
          ],
        },
      },
      [service_output]: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: service_name,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        spec: {
          selector: {
            app: app_name,
          },
          ports: [
            {
              name: 'http',
              protocol: 'TCP',
              port: port,
              targetPort: port,
            },
          ],
          type: 'ClusterIP',
        },
      },
      [postgres_exporter_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: 'postgres-exporter-config',
          namespace: namespace_name,
        },
        data: {
          'queries.yaml': 'pg_stat_activity:\n  query: "SELECT * FROM pg_stat_activity;"\n  metrics:\n    - usage: "LABEL"\n      description: "Name of the user connected to the database"\n      key: "usename"',
        },
      },
    }
    + service_account
    + servicemonitor
    + vault_auth
    + vault_secret,
}
