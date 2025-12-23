{
  resources(
    namespace,
    kafka_cluster_name,
    user_name,
    acls,
    password_secret_ref={},
  )::
    local fmt_context = {
      user_name: user_name,
      namespace: namespace,
    };
    local kafka_user_output = '%(user_name)s-kafka-user.json' % fmt_context;

    {
      [kafka_user_output]: {
        apiVersion: 'kafka.strimzi.io/v1beta2',
        kind: 'KafkaUser',
        metadata: {
          name: user_name,
          namespace: namespace,
          labels: {
            'strimzi.io/cluster': kafka_cluster_name,
          },
        },
        spec: {
          authentication: {
            type: 'scram-sha-512',
            [if password_secret_ref != {} then 'password']: {
              valueFrom: {
                secretKeyRef: password_secret_ref,
              },
            },
          },
          authorization: {
            type: 'simple',
            acls: acls,
          },
        },
      },
    },
}


//[kafka_user_output]: {
//  apiVersion: 'kafka.strimzi.io/v1beta2',
//  kind: 'KafkaUser',
//  metadata: {
//    name: parent_app_name + '-kafka-user',
//    namespace: namespace_name,
//    labels: {
//      'strimzi.io/cluster': namespace_name,
//    },
//  },
//  spec: {
//    authentication: {
//      type: 'scram-sha-512',
//    },
//    authorization: {
//      type: 'simple',
//      acls: [
//        {
//          resource: {
//            type: 'topic',
//            name: 'new-outlets-v1',
//            patternType: 'literal',
//          },
//          operations: [
//            'Create',
//            'Describe',
//            'Read',
//            'Write',
//          ],
//          host: '*',
//        },
//        {
//          resource: {
//            type: 'group',
//            name: 'mds-orderbook',
//            patternType: 'literal',
//          },
//          operations: [
//            'Create',
//            'Describe',
//            'Read',
//            'Write',
//          ],
//          host: '*',
//        },
//      ],
//    },
//  },
//},
