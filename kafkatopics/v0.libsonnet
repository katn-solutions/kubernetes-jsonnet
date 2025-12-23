{
  resources(
    kafka_namespace,
    cluster_name,
    topic_name,
    partitions,
    replicas,
    retention_ms,
    segment_bytes,
  )::
    local fmt_context = {
      topic_name: topic_name,
      namespace: kafka_namespace,
    };
    local topic_output = 'kafka-topic-%(topic_name)s.json' % fmt_context;

    {
      [topic_output]: {
        apiVersion: 'kafka.strimzi.io/v1beta2',
        kind: 'KafkaTopic',
        metadata: {
          name: topic_name,
          labels: {
            'strimzi.io/cluster': cluster_name,
          },
          namespace: kafka_namespace,
        },
        spec: {
          partitions: partitions,
          replicas: replicas,
          config: {
            'retention.ms': retention_ms,
            'segment.bytes': segment_bytes,
          },
        },
      },
    },
}
