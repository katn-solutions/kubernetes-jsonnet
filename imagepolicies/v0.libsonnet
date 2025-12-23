{
  resources(name, namespace, semver)::
    local fmt_context = {
      name: name,
    };

    local policy_output = '%(name)s-imagepolicy.json' % fmt_context;

    {
      [policy_output]: {
        apiVersion: 'image.toolkit.fluxcd.io/v1beta2',
        kind: 'ImagePolicy',
        metadata: {
          name: name,
          namespace: namespace,
        },
        spec: {
          imageRepositoryRef: {
            name: name,
          },
          policy: {
            semver: {
              range: semver,
            },
          },
        },
      },
    },
}
