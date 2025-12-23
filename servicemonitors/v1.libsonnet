{
  resources(
    name,
    namespace,
    labels,
    matchLabels,
    path,
    secretSelector,
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
              path: path,
              authorization: {
                type: 'Bearer',
                credentials: secretSelector,
              },
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
