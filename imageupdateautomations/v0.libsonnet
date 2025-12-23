{
  resources(
    name,
    namespace,
    repo,
    repo_namespace,
    branch,
    path,
  )::
    local fmt_context = {
      name: name,

    };

    local output = '%(name)s-imageupdateautomation.json' % fmt_context;
    local interval = '1m0s';

    {
      [output]: {
        apiVersion: 'image.toolkit.fluxcd.io/v1beta1',
        kind: 'ImageUpdateAutomation',
        metadata: {
          name: name,
          namespace: namespace,
        },
        spec: {
          sourceRef: {
            kind: 'GitRepository',
            name: repo,
            namespace: repo_namespace,
          },
          interval: interval,
          update: {
            path: path,
            strategy: 'Setters',
          },
          git: {
            checkout: {
              ref: {
                branch: branch,
              },
            },
            commit: {
              author: {
                email: 'flux@example.com',
                name: 'flux-image-update-automation',
              },
              messageTemplate: '{{range .Updated.Images}}{{println .}}{{end}}',
            },
            push: {
              branch: branch,
            },
          },
        },
      },
    },
}
