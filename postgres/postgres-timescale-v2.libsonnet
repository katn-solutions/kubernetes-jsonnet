local podmonitors_v0 = import '../podmonitors/v0.libsonnet';

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
    backup_s3_bucket,
    nodeport_ro,
    nodeport_rw,
    admin_role,
    admin_role_secret,
    roles,
    read_only_hostname,
    read_write_hostname,
    affinity,
    pooler_replicas,
    pooler_affinity,
    pooler_parameters,
    pool_mode,
    pg_hba=[],

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

    local bootstrap = if restore_from != '' then { recovery: { source: restore_from } } else { initdb: { database: db_name, owner: admin_role, secret: { name: admin_role_secret }, postInitTemplateSQL: ['CREATE EXTENSION IF NOT EXISTS timescaledb;', 'CREATE EXTENSION IF NOT EXISTS hstore;'] } };

    local restore_path = if restore_from != '' then 's3://%s/' % backup_s3_bucket + restore_from else '';

    local external_clusters = if restore_from != '' then
      [
        {
          name: restore_from,
          barmanObjectStore: {
            destinationPath: restore_path,
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
      ] else [];

    {
      [cluster_output]: {
        apiVersion: 'postgresql.cnpg.io/v1',
        kind: 'Cluster',
        metadata: {
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          affinity: affinity,
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
      [pooler_output]: {
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
    + podmonitors_v0.resources(
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
    ),
}
