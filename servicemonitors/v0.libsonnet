{
  resources(
    name,
    namespace,
    labels,
    matchLabels,
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
            matchLabels: matchLabels,
          },
          endpoints: [
            {
              port: 'http',
              interval: '30s',
              scrapeTimeout: '10s',
              path: '/metrics',
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
