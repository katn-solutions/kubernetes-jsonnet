local podmonitors_v0 = import '../podmonitors/v0.libsonnet';
local promrules_v0 = import '../prometheusrules/v0.libsonnet';
local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';

{
  resources(
    app_name,
    aws_account_number,
    cluster,
    environment,
    namespace_name,
    resources,
    affinity,
    storage_class,
    storage_size,
  )::

    local fmt_context = {
      app_name: app_name,
      cluster: cluster,
      environment: environment,
      namespace_name: namespace_name,
    };

    local server_config_output = 'neo4j-standalone-%(app_name)s-server-config.json' % fmt_context;
    local user_config_output = 'neo4j-standalone-%(app_name)s-user-config.json' % fmt_context;
    local default_config_output = 'neo4j-standalone-%(app_name)s-default-config.json' % fmt_context;
    local user_logs_config_output = 'neo4j-standalone-%(app_name)s-user-logs-config.json' % fmt_context;
    local server_logs_config_output = 'neo4j-standalone-%(app_name)s-server-logs-config.json' % fmt_context;
    local environment_config_output = 'neo4j-standalone-%(app_name)s-environment-config.json' % fmt_context;
    local stateful_set_output = 'neo4j-standalone-%(app_name)s-statefulset.json' % fmt_context;
    local service_output = 'neo4j-standalone-%(app_name)s-service.json' % fmt_context;
    local admin_service_output = 'neo4j-standalone-%(app_name)s-admin-service.json' % fmt_context;

    local service_account = serviceaccounts_v0.resources(
      name='neo4j-' + app_name,
      namespace=namespace_name,
      aws_account_number=aws_account_number,
      iam_role_name='neo4j-' + app_name,
    );

    local config_checksum_key = 'checksum/%(app_name)s-config' % fmt_context;
    local env_checksum_key = 'checksum/%(app_name)s-env' % fmt_context;

    {
      [server_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: '%(app_name)s-k8s-config' % fmt_context,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        data: {
          'server.default_listen_address': '0.0.0.0',
        },
      },
      [user_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: '%(app_name)s-user-config' % fmt_context,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        data: {
          'server.config.strict_validation.enabled': 'false',
          'server.jvm.additional': '-XX:+UseG1GC\n-XX:-OmitStackTraceInFastThrow\n-XX:+AlwaysPreTouch\n-XX:+UnlockExperimentalVMOptions\n-XX:+TrustFinalNonStaticFields\n-XX:+DisableExplicitGC\n-Djdk.nio.maxCachedBufferSize=1024\n-Dio.netty.tryReflectionSetAccessible=true\n-Djdk.tls.ephemeralDHKeySize=2048\n-Djdk.tls.rejectClientInitiatedRenegotiation=true\n-XX:FlightRecorderOptions=stackdepth=256\n-XX:+UnlockDiagnosticVMOptions\n-XX:+DebugNonSafepoints\n--add-opens=java.base/java.nio=ALL-UNNAMED\n--add-opens=java.base/java.io=ALL-UNNAMED\n--add-opens=java.base/sun.nio.ch=ALL-UNNAMED\n-Dlog4j2.disable.jmx=true',
        },
      },
      [default_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: '%(app_name)s-default-config' % fmt_context,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        data: {
          'db.tx_log.rotation.retention_policy': '1 days',
          'server.windows_service_name': 'neo4j',
          'server.logs.config': '/config/server-logs.xml/server-logs.xml',
          'server.logs.user.config': '/config/user-logs.xml/user-logs.xml',
          'server.bolt.thread_pool_max_size': '2000',
          'server.bolt.connection_keep_alive': '30s',
          'server.bolt.connection_keep_alive_for_requests': 'ALL',
          'server.bolt.connection_keep_alive_streaming_scheduling_interval': '30s',
          'internal.dbms.ssl.system.ignore_dot_files': 'true',
          'server.directories.logs': '/logs',
          'server.directories.import': '/import',
          'dbms.ssl.policy.bolt.client_auth': 'NONE',
          'dbms.ssl.policy.https.client_auth': 'NONE',

          // Added performance tuning entries
          'server.memory.heap.initial_size': '8G',
          'server.memory.heap.max_size': '8G',
          'server.memory.pagecache.size': '20G',
          'db.logs.query.enabled': 'VERBOSE',
          'db.logs.query.threshold': '200ms',
          'db.query_cache_size': '10000',
          'server.http.enabled': 'false',
          'server.https.enabled': 'false',
          'db.transaction.concurrent.maximum': '0',
        },
      },
      [server_logs_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: '%(app_name)s-server-logs-config' % fmt_context,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        data: {
          'server-logs.xml': '<?xml version="1.0" encoding="UTF-8"?>\n<!--\n\n    Copyright (c) "Neo4j"\n    Neo4j Sweden AB [http://neo4j.com]\n    This file is a commercial add-on to Neo4j Enterprise Edition.\n\n-->\n<!--\n    This is a log4j 2 configuration file.\n\n    It is highly recommended to keep the original "debug.log" as is, to make sure enough data is captured in case\n    of errors in a format that neo4j developers can work with.\n\n    All configuration values can be queried with the lookup prefix "config:". You can for example, resolve\n    the path to your neo4j home directory with ${config:dbms.directories.neo4j_home}.\n\n    Please consult https://logging.apache.org/log4j/2.x/manual/configuration.html for instructions and\n    available configuration options.\n-->\n<Configuration status="ERROR" monitorInterval="30" packages="org.neo4j.logging.log4j">\n    <Appenders>\n        <!-- Default debug.log, please keep -->\n        <RollingRandomAccessFile name="DebugLog" fileName="${config:server.directories.logs}/debug.log"\n                                 filePattern="$${config:server.directories.logs}/debug.log.%02i">\n            <Neo4jDebugLogLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSSZ}{GMT+0} %-5p [%c{1.}] %m%n"/>\n            <Policies>\n                <SizeBasedTriggeringPolicy size="20 MB"/>\n            </Policies>\n            <DefaultRolloverStrategy fileIndex="min" max="7"/>\n        </RollingRandomAccessFile>\n\n        <RollingRandomAccessFile name="HttpLog" fileName="${config:server.directories.logs}/http.log"\n                                 filePattern="$${config:server.directories.logs}/http.log.%02i">\n            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSSZ}{GMT+0} %-5p %m%n"/>\n            <Policies>\n                <SizeBasedTriggeringPolicy size="20 MB"/>\n            </Policies>\n            <DefaultRolloverStrategy fileIndex="min" max="5"/>\n        </RollingRandomAccessFile>\n\n        <RollingRandomAccessFile name="QueryLog" fileName="${config:server.directories.logs}/query.log"\n                                 filePattern="$${config:server.directories.logs}/query.log.%02i">\n            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSSZ}{GMT+0} %-5p %m%n"/>\n            <Policies>\n                <SizeBasedTriggeringPolicy size="20 MB"/>\n            </Policies>\n            <DefaultRolloverStrategy fileIndex="min" max="7"/>\n        </RollingRandomAccessFile>\n\n        <RollingRandomAccessFile name="SecurityLog" fileName="${config:server.directories.logs}/security.log"\n                                 filePattern="$${config:server.directories.logs}/security.log.%02i">\n            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSSZ}{GMT+0} %-5p %m%n"/>\n            <Policies>\n                <SizeBasedTriggeringPolicy size="20 MB"/>\n            </Policies>\n            <DefaultRolloverStrategy fileIndex="min" max="7"/>\n        </RollingRandomAccessFile>\n    </Appenders>\n\n    <Loggers>\n        <!-- Log levels. One of DEBUG, INFO, WARN, ERROR or OFF -->\n\n        <!-- The debug log is used as the root logger to catch everything -->\n        <Root level="INFO">\n            <AppenderRef ref="DebugLog"/> <!-- Keep this -->\n        </Root>\n\n        <!-- The query log, must be named "QueryLogger" -->\n        <Logger name="QueryLogger" level="INFO" additivity="false">\n            <AppenderRef ref="QueryLog"/>\n        </Logger>\n\n        <!-- The http request log, must be named "HttpLogger" -->\n        <Logger name="HttpLogger" level="INFO" additivity="false">\n            <AppenderRef ref="HttpLog"/>\n        </Logger>\n\n        <!-- The security log, must be named "SecurityLogger" -->\n        <Logger name="SecurityLogger" level="INFO" additivity="false">\n            <AppenderRef ref="SecurityLog"/>\n        </Logger>\n    </Loggers>\n</Configuration>',
        },
      },
      [user_logs_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: '%(app_name)s-user-logs-config' % fmt_context,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        data: {
          'user-logs.xml': '<?xml version="1.0" encoding="UTF-8"?>\n<!--\n\n    Copyright (c) "Neo4j"\n    Neo4j Sweden AB [http://neo4j.com]\n    This file is a commercial add-on to Neo4j Enterprise Edition.\n\n-->\n<!--\n    This is a log4j 2 configuration file that provides maximum flexibility.\n\n    All configuration values can be queried with the lookup prefix "config:". You can for example, resolve\n    the path to your neo4j home directory with ${config:dbms.directories.neo4j_home}.\n\n    Please consult https://logging.apache.org/log4j/2.x/manual/configuration.html for instructions and\n    available configuration options.\n-->\n<Configuration status="ERROR" monitorInterval="30" packages="org.neo4j.logging.log4j">\n\n    <Appenders>\n        <RollingRandomAccessFile name="Neo4jLog" fileName="${config:server.directories.logs}/neo4j.log"\n                                 filePattern="$${config:server.directories.logs}/neo4j.log.%02i">\n            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSSZ}{GMT+0} %-5p %m%n"/>\n            <Policies>\n                <SizeBasedTriggeringPolicy size="20 MB"/>\n            </Policies>\n            <DefaultRolloverStrategy fileIndex="min" max="7"/>\n        </RollingRandomAccessFile>\n\n        <!-- Only used by "neo4j console", will be ignored otherwise -->\n        <Console name="ConsoleAppender" target="SYSTEM_OUT">\n            <PatternLayout pattern="%d{yyyy-MM-dd HH:mm:ss.SSSZ}{GMT+0} %-5p %m%n"/>\n        </Console>\n    </Appenders>\n\n    <Loggers>\n        <!-- Log level for the neo4j log. One of DEBUG, INFO, WARN, ERROR or OFF -->\n        <Root level="INFO">\n            <AppenderRef ref="Neo4jLog"/>\n            <AppenderRef ref="ConsoleAppender"/>\n        </Root>\n    </Loggers>\n\n</Configuration>',
        },
      },
      [environment_config_output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: '%(app_name)s-env' % fmt_context,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        data: {
          NEO4J_AUTH_PATH: '/config/neo4j-auth/NEO4J_AUTH',
          NEO4J_EDITION: 'COMMUNITY_K8S',
          NEO4J_CONF: '/config/',
          K8S_NEO4J_NAME: app_name,
          EXTENDED_CONF: 'yes',
          NEO4J_PLUGINS: '["graph-data-science","apoc","apoc-extended"]',
        },
      },
      [stateful_set_output]: {
        apiVersion: 'apps/v1',
        kind: 'StatefulSet',
        metadata: {
          labels: {
            'helm.neo4j.com/neo4j.name': app_name,
            'helm.neo4j.com/clustering': 'false',
            app: app_name,
            'helm.neo4j.com/instance': app_name,
          },
          name: app_name,
          namespace: namespace_name,
        },
        spec: {
          serviceName: app_name,
          podManagementPolicy: 'Parallel',
          replicas: 1,
          selector: {
            matchLabels: {
              app: app_name,
              'helm.neo4j.com/instance': app_name,
            },
          },
          template: {
            metadata: {
              labels: {
                app: app_name,
                'helm.neo4j.com/neo4j.name': app_name,
                'helm.neo4j.com/clustering': 'false',
                'helm.neo4j.com/pod_category': 'neo4j-instance',
                'helm.neo4j.com/neo4j.loadbalancer': 'include',
                'helm.neo4j.com/instance': app_name,
              },
              annotations: {
                config_checksum_key: '04827aa2eff748b8ebd8b315ca017fd7adddfa665ee1aa438f6f1ace29416aae' % fmt_context,
                env_checksum_key: '41b4e084e139cf8db02b3d7308b7b929be357de1b5192d0f848f0c23b1fafb9e' % fmt_context,
              },
            },
            spec: {
              affinity: affinity,
              tolerations: [
                {
                  key: 'purpose',
                  value: 'neo4j',
                },
              ],
              dnsPolicy: 'ClusterFirst',
              securityContext: {
                fsGroup: 7474,
                fsGroupChangePolicy: 'Always',
                runAsGroup: 7474,
                runAsNonRoot: true,
                runAsUser: 7474,
              },
              terminationGracePeriodSeconds: 3600,
              //              initContainers: [
              //                {
              //                  name: 'file-permissions',
              //                  image: 'busybox:latest',
              //                  command: [
              //                    'chown',
              //                    '-R',
              //                    '7474:7474',
              //                    '/data',
              //                    '/backups',
              //                    '/imports',
              //                    '/licenses',
              //                    '/logs',
              //                    '/metrics',
              //                  ],
              //                  env: [
              //                    {
              //                      name: 'POD_NAME',
              //                      valueFrom: {
              //                        fieldRef: {
              //                          fieldPath: 'metadata.name',
              //                        },
              //                      },
              //                    },
              //                  ],
              //                  volumeMounts: [
              //                    {
              //                      mountPath: '/backups',
              //                      name: 'data',
              //                      subPathExpr: 'backups',
              //                    },
              //                    {
              //                      mountPath: '/data',
              //                      name: 'data',
              //                      subPathExpr: 'data',
              //                    },
              //                    {
              //                      mountPath: '/import',
              //                      name: 'data',
              //                      subPathExpr: 'import',
              //                    },
              //                    {
              //                      mountPath: '/licenses',
              //                      name: 'data',
              //                      subPathExpr: 'licenses',
              //                    },
              //                    {
              //                      mountPath: '/logs',
              //                      name: 'data',
              //                      subPathExpr: 'logs/$(POD_NAME)',
              //                    },
              //                    {
              //                      mountPath: '/metrics',
              //                      name: 'data',
              //                      subPathExpr: 'metrics/$(POD_NAME)',
              //                    },
              //                  ],
              //                }
              //              ],
              containers: [
                {
                  name: 'neo4j',
                  image: 'neo4j:5.26.0',
                  imagePullPolicy: 'IfNotPresent',
                  envFrom: [
                    {
                      configMapRef: {
                        name: '%(app_name)s-env' % fmt_context,
                      },
                    },
                  ],
                  env: [
                    {
                      name: 'HELM_NEO4J_VERSION',
                      value: '5.26.0',
                    },
                    {
                      name: 'HELM_CHART_VERSION',
                      value: '5.26.0',
                    },
                    {
                      name: 'POD_NAME',
                      valueFrom: {
                        fieldRef: {
                          fieldPath: 'metadata.name',
                        },
                      },
                    },
                    {
                      name: 'SERVICE_NEO4J_ADMIN',
                      value: '%(app_name)s-admin.default.svc.cluster.local' % fmt_context,
                    },
                    {
                      name: 'SERVICE_NEO4J_INTERNALS',
                      value: '%(app_name)s-internals.default.svc.cluster.local' % fmt_context,
                    },
                    {
                      name: 'SERVICE_NEO4J',
                      value: '%(app_name)s.default.svc.cluster.local' % fmt_context,
                    },
                  ],
                  ports: [
                    {
                      containerPort: 7474,
                      name: 'http',
                    },
                    {
                      containerPort: 7687,
                      name: 'bolt',
                    },
                  ],
                  resources: resources,
                  securityContext: {
                    capabilities: {
                      drop: [
                        'ALL',
                      ],
                    },
                    runAsGroup: 7474,
                    runAsNonRoot: true,
                    runAsUser: 7474,
                  },
                  volumeMounts: [
                    {
                      mountPath: '/config/neo4j.conf',
                      name: 'neo4j-conf',
                    },
                    {
                      mountPath: '/config/server-logs.xml',
                      name: 'neo4j-server-logs',
                    },
                    {
                      mountPath: '/config/user-logs.xml',
                      name: 'neo4j-user-logs',
                    },
                    {
                      mountPath: '/config/neo4j-auth',
                      name: 'neo4j-auth',
                    },
                    {
                      mountPath: '/backups',
                      name: 'data',
                      subPathExpr: 'backups',
                    },
                    {
                      mountPath: '/data',
                      name: 'data',
                      subPathExpr: 'data',
                    },
                    {
                      mountPath: '/import',
                      name: 'data',
                      subPathExpr: 'import',
                    },
                    {
                      mountPath: '/licenses',
                      name: 'data',
                      subPathExpr: 'licenses',
                    },
                    {
                      mountPath: '/logs',
                      name: 'data',
                      subPathExpr: 'logs/$(POD_NAME)',
                    },
                    {
                      mountPath: '/metrics',
                      name: 'data',
                      subPathExpr: 'metrics/$(POD_NAME)',
                    },
                  ],
                  readinessProbe: {
                    tcpSocket: {
                      port: 7687,
                    },
                    failureThreshold: 20,
                    timeoutSeconds: 10,
                    periodSeconds: 5,
                  },
                  livenessProbe: {
                    tcpSocket: {
                      port: 7687,
                    },
                    failureThreshold: 40,
                    timeoutSeconds: 10,
                    periodSeconds: 5,
                  },
                  startupProbe: {
                    tcpSocket: {
                      port: 7687,
                    },
                    failureThreshold: 1000,
                    periodSeconds: 5,
                  },
                },
              ],
              volumes: [
                {
                  name: 'neo4j-conf',
                  projected: {
                    defaultMode: 288,
                    sources: [
                      {
                        configMap: {
                          name: '%(app_name)s-default-config' % fmt_context,
                        },
                      },
                      {
                        configMap: {
                          name: '%(app_name)s-user-config' % fmt_context,
                        },
                      },
                      {
                        configMap: {
                          name: '%(app_name)s-k8s-config' % fmt_context,
                        },
                      },
                    ],
                  },
                },
                {
                  name: 'neo4j-server-logs',
                  configMap: {
                    name: '%(app_name)s-server-logs-config' % fmt_context,
                  },
                },
                {
                  name: 'neo4j-user-logs',
                  configMap: {
                    name: '%(app_name)s-user-logs-config' % fmt_context,
                  },
                },
                {
                  name: 'neo4j-auth',
                  secret: {
                    secretName: 'neo4j-%(app_name)s' % fmt_context,
                  },
                },
              ],
            },
          },
          volumeClaimTemplates: [
            {
              metadata: {
                name: 'data',
              },
              spec: {
                accessModes: [
                  'ReadWriteOnce',
                ],
                storageClassName: storage_class,
                resources: {
                  requests: {
                    storage: storage_size,
                  },
                },
              },
            },
          ],
        },
      },
      [service_output]: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: app_name,
          namespace: namespace_name,
          labels: {
            'helm.neo4j.com/neo4j.name': app_name,
            app: app_name,
            'helm.neo4j.com/instance': app_name,
            'helm.neo4j.com/service': 'default',
          },
        },
        spec: {
          publishNotReadyAddresses: false,
          type: 'ClusterIP',
          selector: {
            app: app_name,
            'helm.neo4j.com/instance': app_name,
          },
          ports: [
            {
              protocol: 'TCP',
              port: 7687,
              targetPort: 7687,
              name: 'tcp-bolt',
            },
            {
              protocol: 'TCP',
              port: 7474,
              targetPort: 7474,
              name: 'tcp-http',
            },
          ],
        },
      },
      [admin_service_output]: {
        apiVersion: 'v1',
        kind: 'Service',
        metadata: {
          name: '%(app_name)s-admin' % fmt_context,
          namespace: namespace_name,
          labels: {
            'helm.neo4j.com/neo4j.name': app_name,
            app: app_name,
            'helm.neo4j.com/instance': app_name,
            'helm.neo4j.com/service': 'admin',
          },
        },
        spec: {
          publishNotReadyAddresses: true,
          type: 'ClusterIP',
          selector: {
            app: app_name,
            'helm.neo4j.com/instance': app_name,
          },
          ports: [
            {
              protocol: 'TCP',
              port: 7687,
              targetPort: 7687,
              name: 'tcp-bolt',
            },
            {
              protocol: 'TCP',
              port: 7474,
              targetPort: 7474,
              name: 'tcp-http',
            },
          ],
        },
      },
    }
    + service_account,
}
