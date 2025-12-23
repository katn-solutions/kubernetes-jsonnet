local podmonitors = import '../podmonitors/v0.libsonnet';
// TODO needs data sizes added to inputs
// TODO handle ports better and different number of replicas
{
  cluster(
    account_number,
    region,
    cluster,
    environment,
    name,
    namespace_name,
    zk_replicas,
    replicas,
    config,
    super_users,
  )::
    local fmt_context = {
      account_number: account_number,
      region: region,
      cluster: cluster,
      name: name,
      namespace_name: namespace_name,
      environment: environment,

    };
    local cluster_output = 'kafka-%(name)s-cluster.json' % fmt_context;
    local rebalance_output = 'kafka-%(name)s-rebalance.json' % fmt_context;
    local metrics_config_output = 'kafka-%(name)s-metrics-config.json' % fmt_context;
    local metrics_config_name = '%(name)s-metrics-config' % fmt_context;

    local exporter_name = 'kminion' % fmt_context;
    local exporter_deployment_output = exporter_name + '-deployment.json';

    //local exporter_image = '%(account_number)s.dkr.ecr.%(region)s.amazonaws.com/kafka-exporter:v0.0.22' % fmt_context;
    local exporter_image = 'redpandadata/kminion:v2.2.8';

    local bootstrap_url = '%(namespace_name)s-kafka-bootstrap:9092' % fmt_context;

    local podmonitor = podmonitors.resources(
      exporter_name,
      namespace_name,
      [
        {
          port: 'http',
        },
      ],
      {
        app: exporter_name,
      },
    );

    {
      [cluster_output]: {
        apiVersion: 'kafka.strimzi.io/v1beta2',
        kind: 'Kafka',
        metadata: {
          name: name,
          namespace: namespace_name,
        },
        spec: {
          entityOperator: {
            topicOperator: {},
            userOperator: {},
          },
          kafka: {
            config: config,
            listeners: [
              {
                name: 'plain',
                port: 9092,
                tls: false,
                type: 'internal',
                authentication: {
                  type: 'scram-sha-512',
                },
              },
              {
                name: 'tls',
                port: 9093,
                tls: true,
                type: 'internal',
                authentication: {
                  type: 'scram-sha-512',
                },
              },
            ],
            authorization: {
              type: 'simple',
              superUsers: super_users,
            },
            metricsConfig: {
              type: 'jmxPrometheusExporter',
              valueFrom: {
                configMapKeyRef: {
                  key: 'kafka-metrics-config.yml',
                  name: metrics_config_name,
                },
              },
            },
            replicas: replicas,
            storage: {
              type: 'jbod',
              volumes: [
                {
                  deleteClaim: false,
                  id: 0,
                  size: '300Gi',
                  type: 'persistent-claim',
                },
              ],
            },
            version: '3.7.0',
          },
          zookeeper: {
            metricsConfig: {
              type: 'jmxPrometheusExporter',
              valueFrom: {
                configMapKeyRef: {
                  key: 'zookeeper-metrics-config.yml',
                  name: metrics_config_name,
                },
              },
            },
            replicas: zk_replicas,
            storage: {
              deleteClaim: false,
              size: '100Gi',
              type: 'persistent-claim',
            },
          },
        },
      },
      [rebalance_output]: {
        apiVersion: 'kafka.strimzi.io/v1beta2',
        kind: 'KafkaRebalance',
        metadata: {
          name: 'default',
          namespace: namespace_name,
          labels: {
            'strimzi.io/cluster': name,
          },
        },
        spec: {},
      },
      [metrics_config_output]: {
        kind: 'ConfigMap',
        apiVersion: 'v1',
        metadata: {
          name: metrics_config_name,
          namespace: namespace_name,
          labels: {
            app: 'strimzi',
          },
        },
        data: {
          'kafka-metrics-config.yml': "# See https://github.com/prometheus/jmx_exporter for more info about JMX Prometheus Exporter metrics\nlowercaseOutputName: true\nrules:\n# Special cases and very specific rules\n- pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value\n  name: kafka_server_$1_$2\n  type: GAUGE\n  labels:\n    clientId: \"$3\"\n    topic: \"$4\"\n    partition: \"$5\"\n- pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value\n  name: kafka_server_$1_$2\n  type: GAUGE\n  labels:\n    clientId: \"$3\"\n    broker: \"$4:$5\"\n- pattern: kafka.server<type=(.+), cipher=(.+), protocol=(.+), listener=(.+), networkProcessor=(.+)><>connections\n  name: kafka_server_$1_connections_tls_info\n  type: GAUGE\n  labels:\n    cipher: \"$2\"\n    protocol: \"$3\"\n    listener: \"$4\"\n    networkProcessor: \"$5\"\n- pattern: kafka.server<type=(.+), clientSoftwareName=(.+), clientSoftwareVersion=(.+), listener=(.+), networkProcessor=(.+)><>connections\n  name: kafka_server_$1_connections_software\n  type: GAUGE\n  labels:\n    clientSoftwareName: \"$2\"\n    clientSoftwareVersion: \"$3\"\n    listener: \"$4\"\n    networkProcessor: \"$5\"\n- pattern: \"kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+):\"\n  name: kafka_server_$1_$4\n  type: GAUGE\n  labels:\n    listener: \"$2\"\n    networkProcessor: \"$3\"\n- pattern: kafka.server<type=(.+), listener=(.+), networkProcessor=(.+)><>(.+)\n  name: kafka_server_$1_$4\n  type: GAUGE\n  labels:\n    listener: \"$2\"\n    networkProcessor: \"$3\"\n# Some percent metrics use MeanRate attribute\n# Ex) kafka.server<type=(KafkaRequestHandlerPool), name=(RequestHandlerAvgIdlePercent)><>MeanRate\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)Percent\\w*><>MeanRate\n  name: kafka_$1_$2_$3_percent\n  type: GAUGE\n# Generic gauges for percents\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)Percent\\w*><>Value\n  name: kafka_$1_$2_$3_percent\n  type: GAUGE\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)Percent\\w*, (.+)=(.+)><>Value\n  name: kafka_$1_$2_$3_percent\n  type: GAUGE\n  labels:\n    \"$4\": \"$5\"\n# Generic per-second counters with 0-2 key/value pairs\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)PerSec\\w*, (.+)=(.+), (.+)=(.+)><>Count\n  name: kafka_$1_$2_$3_total\n  type: COUNTER\n  labels:\n    \"$4\": \"$5\"\n    \"$6\": \"$7\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)PerSec\\w*, (.+)=(.+)><>Count\n  name: kafka_$1_$2_$3_total\n  type: COUNTER\n  labels:\n    \"$4\": \"$5\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)PerSec\\w*><>Count\n  name: kafka_$1_$2_$3_total\n  type: COUNTER\n# Generic gauges with 0-2 key/value pairs\n- pattern: kafka.(\\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Value\n  name: kafka_$1_$2_$3\n  type: GAUGE\n  labels:\n    \"$4\": \"$5\"\n    \"$6\": \"$7\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+), (.+)=(.+)><>Value\n  name: kafka_$1_$2_$3\n  type: GAUGE\n  labels:\n    \"$4\": \"$5\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)><>Value\n  name: kafka_$1_$2_$3\n  type: GAUGE\n# Emulate Prometheus 'Summary' metrics for the exported 'Histogram's.\n# Note that these are missing the '_sum' metric!\n- pattern: kafka.(\\w+)<type=(.+), name=(.+), (.+)=(.+), (.+)=(.+)><>Count\n  name: kafka_$1_$2_$3_count\n  type: COUNTER\n  labels:\n    \"$4\": \"$5\"\n    \"$6\": \"$7\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+), (.+)=(.*), (.+)=(.+)><>(\\d+)thPercentile\n  name: kafka_$1_$2_$3\n  type: GAUGE\n  labels:\n    \"$4\": \"$5\"\n    \"$6\": \"$7\"\n    quantile: \"0.$8\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+), (.+)=(.+)><>Count\n  name: kafka_$1_$2_$3_count\n  type: COUNTER\n  labels:\n    \"$4\": \"$5\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+), (.+)=(.*)><>(\\d+)thPercentile\n  name: kafka_$1_$2_$3\n  type: GAUGE\n  labels:\n    \"$4\": \"$5\"\n    quantile: \"0.$6\"\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)><>Count\n  name: kafka_$1_$2_$3_count\n  type: COUNTER\n- pattern: kafka.(\\w+)<type=(.+), name=(.+)><>(\\d+)thPercentile\n  name: kafka_$1_$2_$3\n  type: GAUGE\n  labels:\n    quantile: \"0.$4\"\n# KRaft mode: uncomment the following lines to export KRaft related metrics\n# KRaft overall related metrics\n# distinguish between always increasing COUNTER (total and max) and variable GAUGE (all others) metrics\n#- pattern: \"kafka.server<type=raft-metrics><>(.+-total|.+-max):\"\n#  name: kafka_server_raftmetrics_$1\n#  type: COUNTER\n#- pattern: \"kafka.server<type=raft-metrics><>(.+):\"\n#  name: kafka_server_raftmetrics_$1\n#  type: GAUGE\n# KRaft \"low level\" channels related metrics\n# distinguish between always increasing COUNTER (total and max) and variable GAUGE (all others) metrics\n#- pattern: \"kafka.server<type=raft-channel-metrics><>(.+-total|.+-max):\"\n#  name: kafka_server_raftchannelmetrics_$1\n#  type: COUNTER\n#- pattern: \"kafka.server<type=raft-channel-metrics><>(.+):\"\n#  name: kafka_server_raftchannelmetrics_$1\n#  type: GAUGE\n# Broker metrics related to fetching metadata topic records in KRaft mode\n#- pattern: \"kafka.server<type=broker-metadata-metrics><>(.+):\"\n#  name: kafka_server_brokermetadatametrics_$1\n#  type: GAUGE\n",
          'zookeeper-metrics-config.yml': '# See https://github.com/prometheus/jmx_exporter for more info about JMX Prometheus Exporter metrics\nlowercaseOutputName: true\nrules:\n# replicated Zookeeper\n- pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\\\d+)><>(\\\\w+)"\n  name: "zookeeper_$2"\n  type: GAUGE\n- pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\\\d+), name1=replica.(\\\\d+)><>(\\\\w+)"\n  name: "zookeeper_$3"\n  type: GAUGE\n  labels:\n    replicaId: "$2"\n- pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\\\d+), name1=replica.(\\\\d+), name2=(\\\\w+)><>(Packets\\\\w+)"\n  name: "zookeeper_$4"\n  type: COUNTER\n  labels:\n    replicaId: "$2"\n    memberType: "$3"\n- pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\\\d+), name1=replica.(\\\\d+), name2=(\\\\w+)><>(\\\\w+)"\n  name: "zookeeper_$4"\n  type: GAUGE\n  labels:\n    replicaId: "$2"\n    memberType: "$3"\n- pattern: "org.apache.ZooKeeperService<name0=ReplicatedServer_id(\\\\d+), name1=replica.(\\\\d+), name2=(\\\\w+), name3=(\\\\w+)><>(\\\\w+)"\n  name: "zookeeper_$4_$5"\n  type: GAUGE\n  labels:\n    replicaId: "$2"\n    memberType: "$3"\n',
        },
      },
      [exporter_deployment_output]: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: exporter_name,
          namespace: namespace_name,
        },
        spec: {
          replicas: 1,
          selector: {
            matchLabels: {
              app: exporter_name,
            },
          },
          template: {
            metadata: {
              labels: {
                app: exporter_name,
              },
            },
            spec: {
              containers: [
                {
                  name: 'exporter',
                  image: exporter_image,
                  ports: [
                    {
                      containerPort: 8080,
                      name: 'http',
                    },
                  ],
                  env: [
                    {
                      name: 'KAFKA_BROKERS',
                      value: bootstrap_url,
                    },
                    {
                      name: 'KAFKA_CLIENTID',
                      value: 'kminion',
                    },
                    {
                      name: 'KAFKA_SASL_ENABLED',
                      value: 'true',
                    },
                    {
                      name: 'KAFKA_SASL_MECHANISM',
                      value: 'SCRAM-SHA-512',
                    },
                    {
                      name: 'KAFKA_SASL_USERNAME',
                      value: 'exporter-kafka-user',
                    },
                    {
                      name: 'KAFKA_SASL_PASSWORD',
                      valueFrom: {
                        secretKeyRef: {
                          name: 'exporter-kafka-user',
                          key: 'password',
                        },
                      },
                    },
                    {
                      name: 'LOGGER_LEVEL',
                      value: 'info',
                    },
                    {
                      name: 'KAFKA_TLS_ENABLED',
                      value: 'false',
                    },
                  ],
                },
              ],
            },
          },
        },
      },
    } + podmonitor,

  superuser(
    name,
    environment,
    namespace_name,
    kafka_name,
  )::
    local fmt_context = {
      name: name,
      namespace_name: namespace_name,
      environment: environment,
      kafka_name: kafka_name,
    };

    local user_output = 'kafka-%(name)s-super-user-%(name)s.json' % fmt_context;

    {
      [user_output]: {
        apiVersion: 'kafka.strimzi.io/v1beta2',
        kind: 'KafkaUser',
        metadata: {
          name: name,
          namespace: namespace_name,
          labels: {
            'strimzi.io/cluster': kafka_name,
          },
        },
        spec: {
          authentication: {
            type: 'scram-sha-512',
          },
          authorization: {
            type: 'simple',
            acls: [
            ],
          },
        },
      },
    },
}
