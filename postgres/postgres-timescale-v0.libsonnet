local port = 5432;

{
  resources(
    name,
    account_number,
    region,
    cluster,
    environment,
    namespace_name,
    image,
    restore_from,
    replicas,
    storage_size,
    wal_storage_size,
    resources,
    parameters,
    backup_schedule,
    backup_retention,
    backup_s3_bucket,
    nodeport_ro,
    nodeport_rw,
    admin_role,
    admin_role_secret,
    roles,
    read_only_hostname,
    read_write_hostname,

  )::
    local fmt_context = {
      app_name: name,
      cluster: cluster,
      environment: environment,
      namespace: namespace_name,
      account_number: account_number,
    };

    local backup_path = 's3://%s/' % backup_s3_bucket + namespace_name + '/' + name;
    local restore_path = if restore_from != '' then 's3://%s/' % backup_s3_bucket + restore_from else '';
    local iam_role = 'arn:aws:iam::%(account_number)s:role/%(app_name)s-%(namespace)s' % fmt_context;

    local app_name = name;
    local cluster_output = '%(app_name)s-pg-cluster.json' % fmt_context;
    local scheduled_backup_output = '%(app_name)s-pg-backup.json' % fmt_context;

    local db_name = '%(app_name)s_db1' % fmt_context;

    local certificate_output = '%(app_name)s-cert.json' % fmt_context;

    local bootstrap = if restore_from != '' then { recovery: { source: app_name } } else { initdb: { database: db_name, owner: admin_role, secret: { name: admin_role_secret }, postInitTemplateSQL: ['CREATE EXTENSION IF NOT EXISTS timescaledb;', 'CREATE EXTENSION IF NOT EXISTS hstore;'] } };

    {
      [cluster_output]: {
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
          description: app_name + ' db',
          // imageName: '',
          backup: {
            barmanObjectStore: {
              destinationPath: backup_path,
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
            retentionPolicy: backup_retention,
            target: 'prefer-standby',  // 'prefer-standby' is default.  Other option is 'primary'.

          },
          postgresql: {
            shared_preload_libraries: [
              'timescaledb',
            ],
            parameters: parameters,
          },
          bootstrap: bootstrap,
          externalClusters: [
            {
              name: app_name,
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
          ],
          instances: replicas,
          certificates: {
            serverTLSSecret: app_name + '-cert',
            serverCASecret: 'letsencrypt-ca',
          },
          imageName: image,
          storage: {
            size: storage_size,
          },
          walStorage: {
            size: wal_storage_size,
          },
          monitoring: {
            enablePodMonitor: true,
          },
          resources: resources,
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
      [scheduled_backup_output]: {
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
    },
}
