local imagerepos_v0 = import '../imagerepositories/v0.libsonnet';
local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';
local vaults_v0 = import '../vaults/v0.libsonnet';

// TODO imput shard and replica counts
{
  create_clickhouse_installation(
    name,
    namespace_name,
    db_name,
    users,
    zone,  // 'eu-west-2a'
    storage,  //'5Ti'
    aws_account_number,
    region,
    cluster,
    environment,
    image,
    resources,
    shards,
    replicas,
  )::
    local app_name = 'clickhouse';
    local fmt_context = {
      app_name: app_name,
      name: name,
      namespace_name: namespace_name,
      db_name: db_name,
    };

    local chi_output = 'chi-%(name)s.json' % fmt_context;
    local namespaced_name = 'clickhouse-%(namespace_name)s' % fmt_context;
    local service_account_name = app_name;
    local service_account = serviceaccounts_v0.resources(service_account_name, namespace_name, aws_account_number, namespaced_name);
    local secret_mount = environment;
    local secret_path = app_name;
    local secret_refresh = '30s';
    local secret_name = app_name;
    local vault_auth = vaults_v0.auth_resources(
      app_name,
      namespace_name,
      cluster,
      app_name,
      'clickhouse'
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

    //local kafka_user_output = 'clickhouse-kafka-%(namespace_name)s-user.json' % fmt_context;

    local imagerepository = imagerepos_v0.resources(
      app_name,
      namespace_name,
      aws_account_number,
      region,
    );

    local zk_name = '%(app_name)s-zk' % fmt_context;
    local zk_output = '%(app_name)s-zk.json' % fmt_context;
    local zk_svc_name = '%(app_name)s-zk-client' % fmt_context;  // the zk operator makes a service <zk name>-client:2181

    {
      [chi_output]: {
        apiVersion: 'clickhouse.altinity.com/v1',
        kind: 'ClickHouseInstallation',
        metadata: {
          name: name,
          namespace: namespace_name,
        },
        spec: {
          configuration: {
            zookeeper: {
              nodes: [
                {
                  host: zk_svc_name,
                },
              ],
            },
            users: users,
            clusters: [
              {
                name: db_name,
                templates: {
                  podTemplate: db_name,
                },
                layout: {
                  shardsCount: shards,
                  replicasCount: replicas,
                },
              },
            ],
            //            settings: {
            //              'kafka/sasl_mechanism': 'SCRAM-SHA-512',
            //              'kafka/security_protocol': 'SASL_PLAINTEXT',
            //              'kafka/debug': 'all',
            //              'kafka/sasl_username': 'clickhouse-kafka-user',
            //              'kafka/sasl_password': {
            //                valueFrom: {
            //                  secretKeyRef: {
            //                    name: 'clickhouse-kafka-user',
            //                    key: 'password',
            //                  },
            //                },
            //              },
            //            },
          },
          templates: {
            podTemplates: [
              {
                name: db_name,
                spec: {
                  serviceAccountName: service_account_name,
                  containers: [
                    {
                      name: db_name,
                      zone: {
                        values: [
                          zone,
                        ],
                      },
                      distribution: 'OnePerHost',
                      image: image,
                      resources: resources,
                      volumeMounts: [
                        {
                          name: db_name,
                          mountPath: '/var/lib/clickhouse/',
                        },
                      ],
                    },
                  ],
                },
              },
            ],
            volumeClaimTemplates: [
              {
                name: db_name,
                reclaimPolicy: 'Retain',
                spec: {
                  accessModes: ['ReadWriteOnce'],
                  resources: {
                    requests: {
                      storage: storage,
                    },
                  },
                },
              },
            ],
          },
        },
      },
      [zk_output]: {
        apiVersion: 'zookeeper.pravega.io/v1beta1',
        kind: 'ZookeeperCluster',
        metadata: {
          name: zk_name,
          namespace: namespace_name,
        },
        spec: {
          replicas: 3,
        },
      },
      //      [kafka_user_output]: {
      //        apiVersion: 'kafka.strimzi.io/v1beta2',
      //        kind: 'KafkaUser',
      //        metadata: {
      //          name: 'clickhouse-kafka-user',
      //          namespace: namespace_name,
      //          labels: {
      //            'strimzi.io/cluster': namespace_name,
      //          },
      //        },
      //        spec: {
      //          authentication: {
      //            type: 'scram-sha-512',
      //          },
      //          authorization: {
      //            type: 'simple',
      //            acls: [
      //              {
      //                resource: {
      //                  type: 'topic',
      //                  name: 'ts-messages',
      //                  patternType: 'literal',
      //                },
      //                operations: [
      //                  'Create',
      //                  'Describe',
      //                  'Read',
      //                ],
      //                host: '*',
      //              },
      //              {
      //                resource: {
      //                  type: 'group',
      //                  name: 'clickhouse',
      //                  patternType: 'literal',
      //                },
      //                operations: [
      //                  'Create',
      //                  'Describe',
      //                  'Read',
      //                ],
      //                host: '*',
      //              },
      //
      //            ],
      //          },
      //        },
      //      },
    } + service_account + vault_auth + vault_secret + imagerepository,
}
