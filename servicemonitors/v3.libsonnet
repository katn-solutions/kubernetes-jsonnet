{
  resources(
    name,
    namespace,
    labels,
    match_labels,
    path,
    port,
    interval,
    timeout,
  )::
    local fmt_context = {
      name: name,
      namespace: namespace,

    };

    local servicemonitor_output = '%(name)s-servicemonitor.json' % fmt_context;

    {
      [servicemonitor_output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: name,
          labels: labels,
          namespace: namespace,
        },
        spec: {
          selector: {
            matchLabels: match_labels,
          },
          endpoints: [
            {
              port: port,
              interval: '30s',
              scrapeTimeout: '10s',
              path: path,
            },
          ],
          namespaceSelector: {
            matchNames: [
              namespace,
            ],
          },
        },
      },
    },
}
