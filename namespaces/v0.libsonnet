{
  resources(
    name,
    istio,
    sec_profile,
  )::
    local fmt_context = {
      name: name,

    };

    local ns_output = '%(name)s-namespace.json' % fmt_context;

    {
      [ns_output]: {
        apiVersion: 'v1',
        kind: 'Namespace',
        metadata: {
          name: name,
          labels: {
            'istio-injection': istio,
            'pod-security.kubernetes.io/enforce': sec_profile,
            'pod-security.kubernetes.io/enforce-version': 'latest',
          },
        },
      },
    },
}
