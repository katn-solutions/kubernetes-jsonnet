{
  resources(
    name,
    namespace,
    endpoints,
    labels,
  )::

    local fmt_context = {
      name: name,
      namespace: namespace,
    };

    local output = '%(name)s-pod_monitor.json' % fmt_context;
    {
      [output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PodMonitor',
        metadata: {
          name: name,
          namespace: namespace,
          labels: labels,
        },
        spec: {
          podMetricsEndpoints: endpoints,
          selector: {
            matchLabels: labels,
          },
        },
      },
    },
}

//        [pod_monitor_output]: {
//          apiVersion: 'monitoring.coreos.com/v1',
//          kind: 'PodMonitor',
//          metadata: {
//            name: deployment_name,
//            namespace: namespace_name,
//            labels: {
//              app: app_name,
//            },
//          },
//          spec: {
//            selector: {
//              matchLabels: {
//                app: app_name,
//              },
//            },
//            podMetricsEndpoints: [
//              {
//                targetPort: 8080,
//              },
//            ],
//          },
//        },
