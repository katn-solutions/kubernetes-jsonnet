local imagerepos_v0 = import '../imagerepositories/v0.libsonnet';
local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';
local servicemonitors_v0 = import '../servicemonitors/v0.libsonnet';
local vaults_v0 = import '../vaults/v0.libsonnet';

local port = 5432;

{
  resources(
    account_number,
    region,
    cluster,
    environment,
    namespace_name,
    app_name,
    app_restore_from,
    app_replicas,
    app_storage,
    app_resources,
    app_parameters,
    app_backup_schedule,
    app_backup_retention,
    app_backup_s3_bucket,
    hasura_restore_from,
    hasura_replicas,
    hasura_storage,
    hasura_resources,
    hasura_parameters,
    hasura_backup_schedule,
    hasura_backup_retention,
    hasura_backup_s3_bucket,
    roles,
  )::
    local fmt_context = {
      cluster: cluster,
      environment: environment,
      namespace: namespace_name,
      account_number: account_number,
    };

    local iam_role = 'arn:aws:iam::%(account_number)s:role/postgres-%(namespace)s' % fmt_context;

    local app_cluster_output = '%s-pg-cluster.json' % app_name;
    local app_scheduled_backup_output = '%s-pg-backup.json' % app_name;
    local app_backup_path = 's3://%s/' % app_backup_s3_bucket + namespace_name;
    local app_restore_path = if app_restore_from != '' then 's3://%s/' % app_backup_s3_bucket + app_restore_from else '';

    local hasura_app_name = 'hasura-pg';
    local hasura_cluster_output = 'hasura-pg-cluster.json';
    local hasura_scheduled_backup_output = 'hasura-pg-backup.json';
    local hasura_backup_path = 's3://%s/' % hasura_backup_s3_bucket + namespace_name;
    local hasura_restore_path = if hasura_restore_from != '' then 's3://%s/' % hasura_backup_s3_bucket + hasura_restore_from else '';

    //    local prometheus_rule_output = '%(app_name)s-service-prometheusRule.json' % fmt_context;
    //    local prometheus_rule_expression = 'absent(kube_pod_container_info{namespace="%(namespace)s",pod=~"%(app_name)s.+" })' % fmt_context;
    //    local prometheus_duration = '5m';
    //    local prometheus_severity = 'critical';
    //    local prometheus_alert = '%(app_name)s Down (%(cluster)s)' % fmt_context;
    //    local prometheus_message = '%(app_name)s is not running!' % fmt_context;


    local app_bootstrap = if app_restore_from != '' then { recovery: { source: app_name } } else { initdb: { database: '%s_db1' % app_name, owner: app_name, secret: { name: 'pg-role-%s' % app_name } } };

    local hasura_bootstrap = if hasura_restore_from != '' then { recovery: { source: hasura_app_name } } else { initdb: { database: 'hasura_db1', owner: 'hasura', secret: { name: 'pg-role-hasura' } } };

    {
      [app_cluster_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'Cluster',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          affinity: {
            nodeAffinity: {
              requiredDuringSchedulingIgnoredDuringExecution: {
                nodeSelectorTerms: [
                  {
                    matchExpressions: [
                      {
                        key: 'cloud',
                        operator: 'NotIn',
                        values: [
                          'azure',
                        ],
                      },
                    ],
                  },
                ],
              },
            },
          },
          description: '%s application' % app_name,
          // imageName: '',
          backup: {
            barmanObjectStore: {
              destinationPath: app_backup_path,
              s3Credentials: {
                inheritFromIAMRole: true,  // pull from IRSA
              },
              wal: {
                compression: 'gzip',
                encryption: 'aws:kms',  // 'AES256', 'aws:kms', or '' (empty string uses bucket default)
              },
              data: {
                compression: 'gzip',
                encryption: 'aws:kms',  // 'AES256', 'aws:kms', or '' (empty string uses bucket default)
              },
            },
            retentionPolicy: app_backup_retention,
            target: 'prefer-standby',  // 'prefer-standby' is default.  Other option is 'primary'.

          },
          postgresql: {
            parameters: app_parameters,
          },
          bootstrap: app_bootstrap,
          externalClusters: [
            {
              name: app_name,
              barmanObjectStore: {
                destinationPath: app_restore_path,
                s3Credentials: {
                  inheritFromIAMRole: true,  // pull from IRSA
                },
                wal: {
                  compression: 'gzip',
                  encryption: 'aws:kms',  // 'AES256', 'aws:kms', or '' (empty string uses bucket default)
                  maxParallel: 8,
                },
                data: {
                  compression: 'gzip',
                  encryption: 'aws:kms',  // 'AES256', 'aws:kms', or '' (empty string uses bucket default)
                },
              },
            },
          ],
          instances: app_replicas,
          storage: {
            size: app_storage,
          },
          monitoring: {
            enablePodMonitor: true,
          },
          resources: app_resources,
          serviceAccountTemplate: {
            metadata: {
              name: app_name,
              annotations: {
                'eks.amazonaws.com/role-arn': iam_role,
              },
            },
          },
          managed: {
            services: {
              additional: [
                {
                  selectorType: 'rw',
                  serviceTemplate: {
                    metadata: {
                      name: '%s-external-rw' % app_name,
                      labels: {
                        'cnpg.io/cluster': app_name,
                      },
                    },
                    spec: {
                      type: 'NodePort',
                      ports: [
                        {
                          name: 'postgres',
                          port: 5432,
                          protocol: 'TCP',
                          targetPort: 5432,
                        },
                      ],
                    },
                  },
                },
                {
                  selectorType: 'ro',
                  serviceTemplate: {
                    metadata: {
                      name: '%s-external-ro' % app_name,
                      labels: {
                        'cnpg.io/cluster': app_name,
                      },
                    },
                    spec: {
                      type: 'NodePort',
                      ports: [
                        {
                          name: 'postgres',
                          port: 5432,
                          protocol: 'TCP',
                          targetPort: 5432,
                        },
                      ],
                    },
                  },
                },
              ],
            },
            roles: roles,
          },
        },
      },
      [app_scheduled_backup_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'ScheduledBackup',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          schedule: app_backup_schedule,
          backupOwnerReference: 'self',
          cluster: {
            name: app_name,
          },
        },
      },
      [hasura_cluster_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'Cluster',
        metadata: {
          name: hasura_app_name,
          namespace: namespace_name,
        },
        spec: {
          affinity: {
            nodeAffinity: {
              requiredDuringSchedulingIgnoredDuringExecution: {
                nodeSelectorTerms: [
                  {
                    matchExpressions: [
                      {
                        key: 'cloud',
                        operator: 'NotIn',
                        values: [
                          'azure',
                        ],
                      },
                    ],
                  },
                ],
              },
            },
          },
          description: 'hasura database',
          backup: {
            barmanObjectStore: {
              destinationPath: hasura_backup_path,
              s3Credentials: {
                inheritFromIAMRole: true,  // pull from IRSA
              },
              wal: {
                compression: 'gzip',
                encryption: 'aws:kms',
              },
              data: {
                compression: 'gzip',
                encryption: 'aws:kms',
              },
            },
            retentionPolicy: hasura_backup_retention,
            target: 'prefer-standby',

          },
          postgresql: {
            parameters: hasura_parameters,
          },
          bootstrap: hasura_bootstrap,
          externalClusters: [
            {
              name: hasura_app_name,
              barmanObjectStore: {
                destinationPath: hasura_restore_path,
                s3Credentials: {
                  inheritFromIAMRole: true,  // pull from IRSA
                },
                wal: {
                  compression: 'gzip',
                  encryption: 'aws:kms',  // 'AES256', 'aws:kms', or '' (empty string uses bucket default)
                  maxParallel: 8,
                },
                data: {
                  compression: 'gzip',
                  encryption: 'aws:kms',  // 'AES256', 'aws:kms', or '' (empty string uses bucket default)
                },
              },
            },
          ],
          instances: hasura_replicas,
          storage: {
            size: hasura_storage,
          },
          monitoring: {
            enablePodMonitor: true,
          },
          resources: hasura_resources,
          serviceAccountTemplate: {
            metadata: {
              name: hasura_app_name,
              annotations: {
                'eks.amazonaws.com/role-arn': iam_role,
              },
            },
          },
          managed: {
            roles: [
              {
                name: 'hasura',
                ensure: 'present',
                login: true,
                superuser: true,
                passwordSecret: {
                  name: 'pg-role-hasura',
                },
              },
            ],
          },
        },
      },
      [hasura_scheduled_backup_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'ScheduledBackup',
        metadata: {
          name: hasura_app_name,
          namespace: namespace_name,
        },
        spec: {
          schedule: hasura_backup_schedule,
          backupOwnerReference: 'self',
          cluster: {
            name: hasura_app_name,
          },
        },
      },
    }
    + vaults_v0.auth_resources(
      app_name,  // name
      namespace_name,  // namespace
      cluster,  // cluster
      'postgres',  // role
      app_name,  // serviceaccount
    )
    + vaults_v0.secret_resources(
      'pg-role-hasura',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-hasura',  // secret path
      'pg-role-hasura',  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-%s' % app_name,  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-%s' % app_name,  // secret path
      'pg-role-%s' % app_name,  // secret name
      '30s',  // refresh period
    )
    + vaults_v0.secret_resources(
      'pg-role-account-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-account-service',  // secret path
      'pg-role-account-service',  // secreet name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-api-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-api-service',  // secret path
      'pg-role-api-service',  // secreet name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-asset-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-asset-service',  // secret path
      'pg-role-asset-service',  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-fusionauth',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-fusionauth',  // secret path
      'pg-role-fusionauth',  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-scanning-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-scanning-service',  // secret path
      'pg-role-scanning-service',  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-%s' % app_name,  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-%s' % app_name,  // secret path
      'pg-role-%s' % app_name,  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-trading-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-trading-service',  // secret path
      'pg-role-trading-service',  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-venue-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-venue-service',  // secret path
      'pg-role-venue-service',  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-wallet-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-wallet-service',  // secret path
      'pg-role-wallet-service',  // secret name
      '30s',
    )
    + vaults_v0.secret_resources(
      'pg-role-grafana-service',  // vault static secret name
      namespace_name,  // namespace
      cluster,  // cluster
      app_name,  // auth name
      environment,  // secret mount
      'pg-role-grafana-service',  // secret path
      'pg-role-grafana-service',  // secret name
      '30s',
    ),
}
