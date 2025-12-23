{
  resources(
    name,
    namespace_name,
    interval,
    ref,
    secret_ref,
    url,
  )::
    local fmt_context = {
      name: name,
    };

    local output = '%(name)s-gitrepository.json' % fmt_context;

    {
      [output]: {
        apiVersion: 'source.toolkit.fluxcd.io/v1',
        kind: 'GitRepository',
        metadata: {
          name: name,
          namespace: namespace_name,
        },
        spec: {
          interval: interval,
          ref: ref,
          secretRef: secret_ref,
          url: url,
          recurseSubmodules: false,
        },

      },
    },
}
