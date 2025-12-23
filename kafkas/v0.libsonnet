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
    bootstrap_port,
    super_users,
    hostname,
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
    //    local logs_config_output = 'kafka-%(name)s-logs-config.json' % fmt_context;
    //    local logs_config_name = '%(name)s-logs-config' % fmt_context;
    local cert_output = 'kafka-%(name)s-certificate.json' % fmt_context;
    local cert_name = 'kafka-%(name)s-cert' % fmt_context;
    local cert_secret = '%(name)s-cert' % fmt_context;

    local exporter_name = 'kminion' % fmt_context;
    local exporter_deployment_output = exporter_name + '-deployment.json';

    //local exporter_image = '%(account_number)s.dkr.ecr.%(region)s.amazonaws.com/kafka-exporter:v0.0.22' % fmt_context;
    local exporter_image = 'redpandadata/kminion:v2.2.8';

    local bootstrap_url = '%(namespace_name)s-kafka-bootstrap:9092' % fmt_context;

    local ts_messages_topic_promrule_name = 'kafka-ts-messages';
    local ts_messages_topic_promrule_output = 'kafka-%(name)s-ts-messages-topic-promRule.json' % fmt_context;
    local ts_messages_topic_prometheus_rule_expression = 'avg by (group_id,topic_name) (kminion_kafka_consumer_group_topic_lag{group_id="clickhouse", topic_name="ts-messages"}) > 2000000 ' % fmt_context;
    local ts_messages_topic_promrule_alert = 'Kafka Consumer Lag (General) Over Limit (%(cluster)s %(namespace_name)s)' % fmt_context;
    local ts_messages_topic_promrule_message = 'Kafka Consumer Lag (General) Over Limit (%(cluster)s %(namespace_name)s)' % fmt_context;
    local ts_messages_topic_promrule_duration = '5m';
    local ts_messages_topic_promrule_severity = 'critical';

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
          cruiseControl: {},
          entityOperator: {
            topicOperator: {},
            userOperator: {},
          },
          kafka: {
            config: {
              'default.replication.factor': 3,
              'inter.broker.protocol.version': '3.5',
              'min.insync.replicas': 2,
              'offsets.topic.replication.factor': 3,
              'transaction.state.log.min.isr': 2,
              'transaction.state.log.replication.factor': 3,
            },
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
              {
                name: 'external',
                port: 9094,
                tls: true,
                type: 'nodeport',
                authentication: {
                  type: 'scram-sha-512',
                },
                configuration: {
                  preferredNodePortAddressType: 'ExternalIP',
                  brokerCertChainAndKey: {
                    secretName: cert_secret,
                    certificate: 'tls.crt',
                    key: 'tls.key',
                  },
                  bootstrap: {
                    nodePort: bootstrap_port,
                  },
                  brokers: [
                    {
                      advertisedHost: hostname,
                      advertisedPort: bootstrap_port + 1,
                      broker: 0,
                      nodePort: bootstrap_port + 1,
                    },
                    {
                      advertisedHost: hostname,
                      advertisedPort: bootstrap_port + 2,
                      broker: 1,
                      nodePort: bootstrap_port + 2,
                    },
                    {
                      advertisedHost: hostname,
                      advertisedPort: bootstrap_port + 3,
                      broker: 2,
                      nodePort: bootstrap_port + 3,
                    },
                    {
                      advertisedHost: hostname,
                      advertisedPort: bootstrap_port + 4,
                      broker: 3,
                      nodePort: bootstrap_port + 4,
                    },
                  ],
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
            //            logging: {
            //              type: 'external',
            //              valueFrom: {
            //                configMapKeyRef: {
            //                  name: logs_config_name,
            //                  key: 'log4j.properties'
            //                }
            //              }
            //            },
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
            template: {
              pod: {
                affinity: {
                  podAntiAffinity: {
                    requiredDuringSchedulingIgnoredDuringExecution: [
                      {
                        labelSelector: {
                          matchExpressions: [
                            {
                              key: 'strimzi.io/name',
                              operator: 'In',
                              values: [
                                name + '-kafka',
                              ],
                            },
                          ],
                        },
                        topologyKey: 'kubernetes.io/hostname',
                      },
                    ],
                  },
                },
                //                tolerations: [
                //                  {
                //                    key: 'Purpose',
                //                    value: 'Kafka',
                //                    effect: 'NoSchedule',
                //                  },
                //                ],
              },
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
      //      [logs_config_output]: {
      //        kind: 'ConfigMap',
      //        apiVersion: 'v1',
      //        metadata: {
      //          name: logs_config_name,
      //          namespace: namespace_name,
      //          labels: {
      //            app: 'strimzi',
      //          },
      //        },
      //        data: {
      //          'log4j.properties': |||
      //            log4j.rootLogger=INFO, stdout
      ////            log4j.rootLogger=INFO, stdout, kafkaAppender
      //
      //            log4j.appender.stdout=org.apache.log4j.ConsoleAppender
      //            log4j.appender.stdout.layout=com.github.wildbeavers.log4j12jsonlayout.JsonLayout
      //            log4j.appender.stdout.layout.DatePattern=yyyy-MM-dd HH:mm:ss,SSS
      //|||
      //            log4j.appender.kafkaAppender=org.apache.log4j.DailyRollingFileAppender
      //            log4j.appender.kafkaAppender.DatePattern='.'yyyy-MM-dd-HH
      //            log4j.appender.kafkaAppender.File=${kafka.logs.dir}/server.log
      //            log4j.appender.kafkaAppender.layout=org.apache.log4j.JsonLayout
      //
      //            log4j.appender.stateChangeAppender=org.apache.log4j.DailyRollingFileAppender
      //            log4j.appender.stateChangeAppender.DatePattern='.'yyyy-MM-dd-HH
      //            log4j.appender.stateChangeAppender.File=${kafka.logs.dir}/state-change.log
      //            log4j.appender.stateChangeAppender.layout=org.apache.log4j.JsonLayout
      //
      //            log4j.appender.requestAppender=org.apache.log4j.DailyRollingFileAppender
      //            log4j.appender.requestAppender.DatePattern='.'yyyy-MM-dd-HH
      //            log4j.appender.requestAppender.File=${kafka.logs.dir}/kafka-request.log
      //            log4j.appender.requestAppender.layout=org.apache.log4j.JsonLayout
      //
      //            log4j.appender.cleanerAppender=org.apache.log4j.DailyRollingFileAppender
      //            log4j.appender.cleanerAppender.DatePattern='.'yyyy-MM-dd-HH
      //            log4j.appender.cleanerAppender.File=${kafka.logs.dir}/log-cleaner.log
      //            log4j.appender.cleanerAppender.layout=org.apache.log4j.JsonLayout
      //
      //            log4j.appender.controllerAppender=org.apache.log4j.DailyRollingFileAppender
      //            log4j.appender.controllerAppender.DatePattern='.'yyyy-MM-dd-HH
      //            log4j.appender.controllerAppender.File=${kafka.logs.dir}/controller.log
      //            log4j.appender.controllerAppender.layout=org.apache.log4j.JsonLayout
      //
      //            log4j.appender.authorizerAppender=org.apache.log4j.DailyRollingFileAppender
      //            log4j.appender.authorizerAppender.DatePattern='.'yyyy-MM-dd-HH
      //            log4j.appender.authorizerAppender.File=${kafka.logs.dir}/kafka-authorizer.log
      //            log4j.appender.authorizerAppender.layout=org.apache.log4j.JsonLayout
      //
      //            # Change the line below to adjust ZK client logging
      //            log4j.logger.org.apache.zookeeper=INFO
      //
      //            # Change the two lines below to adjust the general broker logging level (output to server.log and stdout)
      //            log4j.logger.kafka=INFO
      //            log4j.logger.org.apache.kafka=INFO
      //
      //            # Change to DEBUG or TRACE to enable request logging
      //            log4j.logger.kafka.request.logger=WARN, requestAppender
      //            log4j.additivity.kafka.request.logger=false
      //
      //            # Uncomment the lines below and change log4j.logger.kafka.network.RequestChannel$ to TRACE for additional output
      //            # related to the handling of requests
      //            #log4j.logger.kafka.network.Processor=TRACE, requestAppender
      //            #log4j.logger.kafka.server.KafkaApis=TRACE, requestAppender
      //            #log4j.additivity.kafka.server.KafkaApis=false
      //            log4j.logger.kafka.network.RequestChannel$=WARN, requestAppender
      //            log4j.additivity.kafka.network.RequestChannel$=false
      //
      //            # Change the line below to adjust KRaft mode controller logging
      //            log4j.logger.org.apache.kafka.controller=INFO, controllerAppender
      //            log4j.additivity.org.apache.kafka.controller=false
      //
      //            # Change the line below to adjust ZK mode controller logging
      //            log4j.logger.kafka.controller=TRACE, controllerAppender
      //            log4j.additivity.kafka.controller=false
      //
      //            log4j.logger.kafka.log.LogCleaner=INFO, cleanerAppender
      //            log4j.additivity.kafka.log.LogCleaner=false
      //
      //            log4j.logger.state.change.logger=INFO, stateChangeAppender
      //            log4j.additivity.state.change.logger=false
      //
      //            # Access denials are logged at INFO level, change to DEBUG to also log allowed accesses
      //            log4j.logger.kafka.authorizer.logger=INFO, authorizerAppender
      //            log4j.additivity.kafka.authorizer.logger=false
      //|||
      //        }
      //      },
      [cert_output]: {
        apiVersion: 'cert-manager.io/v1',
        kind: 'Certificate',
        metadata: {
          name: cert_name,
          namespace: namespace_name,
        },
        spec: {
          dnsNames: [
            hostname,
          ],
          issuerRef: {
            group: 'cert-manager.io',
            kind: 'ClusterIssuer',
            name: 'letsencrypt',
          },
          secretName: cert_secret,
          usages: [
            'digital signature',
            'key encipherment',
          ],
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
                  //                  volumeMounts: [
                  //                    {
                  //                      name: 'config',
                  //                      mountPath: '/etc/kminion',
                  //                    },
                  //                  ],
                },
              ],
              //              volumes: [
              //                {
              //                  name: 'config',
              //                  configMap: {
              //                    name: 'kminion',
              //                  },
              //                },
              //              ],
            },
          },
        },
      },
      //      [exporter_config_output]: {
      //        kind: 'ConfigMap',
      //        apiVersion: 'v1',
      //        metadata: {
      //          name: exporter_name,
      //          namespace: namespace_name,
      //          labels: {
      //            app: 'kminion',
      //          },
      //        },
      //        data: {},
      //      },
      [ts_messages_topic_promrule_output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: ts_messages_topic_promrule_name,
          namespace: namespace_name,
          labels: {
            app: 'kafka',
            component: ts_messages_topic_promrule_name,
          },
        },
        spec: {
          groups: [
            {
              name: ts_messages_topic_promrule_name,
              rules: [
                {
                  alert: ts_messages_topic_promrule_alert,
                  annotations: {
                    message: ts_messages_topic_promrule_message,
                  },
                  expr: ts_messages_topic_prometheus_rule_expression,
                  'for': ts_messages_topic_promrule_duration,
                  labels: {
                    app: 'kafka',
                    component: ts_messages_topic_promrule_name,
                    severity: ts_messages_topic_promrule_severity,
                  },
                },
              ],
            },
          ],
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
