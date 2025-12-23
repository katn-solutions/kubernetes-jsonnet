local port = 5432;
local podmonitors_v0 = import '../podmonitors/v0.libsonnet';
local prometheusrules_v2 = import '../prometheusrules/v2.libsonnet';

{
  resources(
    name,
    db_name,
    serviceaccount_name,
    account_number,
    iam_role,
    region,
    cluster,
    environment,
    namespace_name,
    image,
    restore_from,
    replicas,
    data_storage_size,
    data_storage_class,
    wal_storage_size,
    wal_storage_class,
    resources,
    parameters,
    backup={},
    backup_schedule=null,
    backup_s3_bucket='',
    nodeport_ro,
    nodeport_rw,
    admin_role,
    admin_role_secret,
    roles,
    read_only_hostname,
    read_write_hostname,
    affinity={},
    pooler_replicas,
    pooler_affinity,
    pooler_parameters,
    pool_mode,
    restore_path='',
    restore_server_name='',
    recovery_target={},
    purpose='',
    stream_from_host='',
    stream_from_port='5432',
    stream_from_secret='',
    stream_from_ssl_root_cert_secret='',
    stream_from_ssl_root_cert_key='ca.crt',
    pg_hba=[],
    enable_pooler=true,

  )::
    local fmt_context = {
      app_name: name,
      cluster: cluster,
      environment: environment,
      namespace: namespace_name,
      account_number: account_number,
      iam_role: iam_role,
    };

    local iam_role = 'arn:aws:iam::%(account_number)s:role/%(iam_role)s-%(namespace)s' % fmt_context;

    local app_name = name;
    local cluster_output = '%(app_name)s-pg-cluster.json' % fmt_context;
    local scheduled_backup_output = '%(app_name)s-pg-backup.json' % fmt_context;
    local pooler_output = '%(app_name)s-pooler.json' % fmt_context;

    local certificate_output = '%(app_name)s-cert.json' % fmt_context;

    local bootstrap =
      if stream_from_host != '' then {
        pg_basebackup: {
          source: restore_from,
          database: db_name,
          owner: admin_role,
        },
      }
      else if restore_from != '' then {
        recovery: {
          source: restore_from,
          database: db_name,
          owner: admin_role,
        } + (if std.length(recovery_target) > 0 then { recoveryTarget: recovery_target } else {}),
      }
      else {
        initdb: {
          database: db_name,
          owner: admin_role,
          secret: { name: admin_role_secret },
          postInitTemplateSQL: [
            'CREATE EXTENSION IF NOT EXISTS timescaledb;',
            'CREATE EXTENSION IF NOT EXISTS hstore;',
          ],
        },
      };

    local restore_path_computed = if restore_path != '' then restore_path else
      if restore_from != '' && backup_s3_bucket != '' then 's3://%s/' % backup_s3_bucket + restore_from else '';

    local restore_server_name_computed = if restore_server_name != '' then restore_server_name else restore_from;

    local affinity_computed = if purpose != '' then {
      nodeAffinity: {
        requiredDuringSchedulingIgnoredDuringExecution: {
          nodeSelectorTerms: [
            {
              matchExpressions: [
                {
                  key: 'purpose',
                  operator: 'In',
                  values: [purpose],
                },
              ],
            },
          ],
        },
      },
      tolerations: [
        {
          effect: 'NoSchedule',
          operator: 'Equal',
          key: 'purpose',
          value: purpose,
        },
      ],
    } else affinity;

    local external_clusters =
      if stream_from_host != '' then
        [
          {
            name: restore_from,
            connectionParameters: {
              host: stream_from_host,
              port: stream_from_port,
              user: 'mds_streaming_replica',
              dbname: 'postgres',
              sslmode: 'verify-full',
            },
            password: {
              name: stream_from_secret,
              key: 'password',
            },
          }
          + (if stream_from_ssl_root_cert_secret != '' then {
               sslRootCert: {
                 name: stream_from_ssl_root_cert_secret,
                 key: stream_from_ssl_root_cert_key,
               },
             } else {}),
        ]
      else if restore_from != '' then
        [
          {
            name: restore_from,
            barmanObjectStore: {
              destinationPath: restore_path_computed,
              serverName: restore_server_name_computed,
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
        ]
      else [];

    {
      [cluster_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'Cluster',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          affinity: affinity_computed,
          description: app_name + ' db',
          imageName: image,
          backup: backup,
          postgresql: {
            shared_preload_libraries: [
              'timescaledb',
              'pg_stat_statements',
            ],
            parameters: parameters,
          } + (if std.length(pg_hba) > 0 then { pg_hba: pg_hba } else {}),
          bootstrap: bootstrap,
          externalClusters: external_clusters,
          instances: replicas,
          certificates: {
            serverTLSSecret: app_name + '-cert',
            serverCASecret: 'letsencrypt-ca',
          },
          storage: {
            pvcTemplate: {
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: data_storage_size,
                },
              },
              storageClassName: data_storage_class,
            },
          },
          walStorage: {
            pvcTemplate: {
              accessModes: [
                'ReadWriteOnce',
              ],
              resources: {
                requests: {
                  storage: wal_storage_size,
                },
              },
              storageClassName: wal_storage_class,
            },
          },
          monitoring: {
            enablePodMonitor: true,
          },
          resources: resources,
          serviceAccountTemplate: {
            metadata: {
              name: serviceaccount_name,
              annotations: {
                'eks.amazonaws.com/role-arn': iam_role,
              },
            },
          },
          managed: {
            services: {
              additional: [
                {
                  selectorType: 'ro',
                  updateStrategy: 'replace',
                  serviceTemplate: {
                    metadata: {
                      name: app_name + '-pg-ro-external',
                      labels: {
                        'cnpg.io/cluster': app_name + '-pg',
                      },
                    },
                    spec: {
                      type: 'NodePort',
                      ports: [
                        {
                          name: 'postgres',
                          nodePort: nodeport_ro,
                          port: 5432,
                          protocol: 'TCP',
                          targetPort: 5432,
                        },
                      ],
                    },
                  },
                },
                {
                  selectorType: 'rw',
                  updateStrategy: 'replace',
                  serviceTemplate: {
                    metadata: {
                      name: app_name + '-pg-rw-external',
                      labels: {
                        'cnpg.io/cluster': app_name + '-pg',
                      },
                    },
                    spec: {
                      type: 'NodePort',
                      ports: [
                        {
                          name: 'postgres',
                          nodePort: nodeport_rw,
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
      [if backup_schedule != null then scheduled_backup_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'ScheduledBackup',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          schedule: backup_schedule,
          backupOwnerReference: 'self',
          cluster: {
            name: app_name,
          },
        },
      },
      [if enable_pooler then pooler_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'Pooler',
        metadata: {
          name: app_name + '-pooler',
          namespace: namespace_name,
        },
        spec: {
          cluster: {
            name: app_name,
          },
          instances: pooler_replicas,
          type: 'rw',
          pgbouncer: {
            poolMode: pool_mode,
            parameters: pooler_parameters,
          },
          template: {
            metadata: {
              labels: {
                app: app_name + '-pooler',
              },
            },
            spec: {
              containers: [],
              affinity: pooler_affinity,
            },
          },
        },
      },
      [certificate_output]: {
        apiVersion: 'cert-manager.io/v1',
        kind: 'Certificate',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          dnsNames: [
            read_only_hostname,
            read_write_hostname,
          ],
          issuerRef: {
            kind: 'ClusterIssuer',
            name: 'letsencrypt',
          },
          secretName: app_name + '-cert',
        },
      },
    }
    + (if enable_pooler then podmonitors_v0.resources(
         name=app_name + '-pooler',
         namespace=namespace_name,
         endpoints=[
           {
             targetPort: '9127',
           },
         ],
         labels={
           app: app_name + '-pooler',
         },
       ) else {})
    + prometheusrules_v2.resources(
      app_name=app_name,
      component_name='database',
      namespace=namespace_name,
      rule_groups=[
        {
          name: app_name + '-wal-archiving',
          rules: [
            {
              alert: 'PostgresWALArchivingBehind',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.pod }} has {{ $value }} WAL segments waiting to be archived. WAL archiving may be falling behind.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/wal-archiving-behind.md',
              },
              expr: 'cnpg_collector_pg_wal_archive_status{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*",value="ready"} > 750',
              'for': '30m',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
            {
              alert: 'PostgresWALArchivingFailing',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.pod }} is experiencing WAL archiving failures. Rate: {{ $value | humanize }} failures/sec.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/wal-archiving-failing.md',
              },
              expr: 'rate(cnpg_pg_stat_archiver_failed_count{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*"}[5m]) > 0',
              'for': '10m',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
          ],
        },
        {
          name: app_name + '-backup',
          rules: [
            {
              alert: 'PostgresNoRecentBackup',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.name }} has not had a completed backup in over 30 hours. Check ScheduledBackup and Backup resources.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/no-recent-backup.md',
              },
              expr: '(time() - max by (namespace, name) (kube_backup_status_startedAt{namespace="' + namespace_name + '",backup=~"' + app_name + '-.*"})) > 108000',
              'for': '1h',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
            {
              alert: 'PostgresBackupFailed',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.backup }} backup has failed. Phase: {{ $labels.phase }}',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/backup-failed.md',
              },
              expr: 'kube_backup_status_phase{namespace="' + namespace_name + '",backup=~"' + app_name + '-.*",phase="failed"} == 1',
              'for': '10m',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
          ],
        },
        {
          name: app_name + '-transactions',
          rules: [
            {
              alert: 'PostgresLongRunningTransaction',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.pod }} has a transaction running for {{ $value | humanizeDuration }}. Long transactions can cause bloat and replication lag.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/long-running-transaction.md',
              },
              expr: 'max by (namespace, pod) (cnpg_backends_max_tx_duration_seconds{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*"}) > 1800',
              'for': '10m',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
            {
              alert: 'PostgresTransactionIDWraparoundRisk',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.pod }} transaction ID age is {{ $value }}, approaching wraparound limit. Vacuum may be needed.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/transaction-id-wraparound.md',
              },
              expr: 'max by (namespace, pod) (cnpg_pg_database_xid_age{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*"}) > 1500000000',
              'for': '1h',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
          ],
        },
        {
          name: app_name + '-deadlocks-blocking',
          rules: [
            {
              alert: 'PostgresDeadlocks',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.pod }} is experiencing deadlocks. Rate: {{ $value | humanize }} deadlocks/sec.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/deadlocks.md',
              },
              expr: 'rate(cnpg_pg_stat_database_deadlocks{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*",datname!=""}[5m]) > 0.1',
              'for': '10m',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
            {
              alert: 'PostgresHighBlockedQueries',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.pod }} has {{ $value }} queries blocked waiting for locks.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/blocked-queries.md',
              },
              expr: 'cnpg_backends_waiting_total{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*"} > 10',
              'for': '10m',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
          ],
        },
        {
          name: app_name + '-connections',
          rules: [
            {
              alert: 'PostgresConnectionsNearLimit',
              annotations: {
                message: 'PostgreSQL cluster {{ $labels.namespace }}/{{ $labels.pod }} is using {{ $value | humanizePercentage }} of max_connections.',
                runbook_url: 'https://github.com/<YOUR-ORG>/runbooks/blob/main/postgres/connections-near-limit.md',
              },
              expr: '100 * sum by (namespace, pod) (cnpg_backends_total{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*"}) / sum by (namespace, pod) (cnpg_pg_settings_setting{namespace="' + namespace_name + '",pod=~"' + app_name + '-.*",name="max_connections"}) > 80',
              'for': '10m',
              labels: {
                app: app_name,
                component: 'database',
                severity: 'critical',
              },
            },
          ],
        },
      ],
    ),
}
