{
  resources(
    name,
    namespace,
    data,
  )::
    local fmt_context = {
      name: name,
      namespace: namespace,

    };

    local output = '%(name)s-configmap.json' % fmt_context;

    {
      [output]: {
        apiVersion: 'v1',
        kind: 'ConfigMap',
        metadata: {
          name: name,
          namespace: namespace,
        },
        data: data,
      },
    },
}
