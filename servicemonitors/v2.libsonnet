{
  resources(
    name,
    namespace,
    labels,
    matchLabels,
    port,
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
              port: port,
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
