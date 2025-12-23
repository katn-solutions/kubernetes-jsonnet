{
  resources(
    name,
    namespace,
    repo,
    repo_namespace,
    path,
    prune,
    target_namespace=null,
    patches=null,
  )::
    local fmt_context = {
      name: name,
    };

    local kustomization_output = '%(name)s-kustomization.json' % fmt_context;
    local interval = '10m0s';

    local base_spec = {
      interval: interval,
      path: path,
      prune: prune,
      sourceRef: {
        kind: 'GitRepository',
        name: repo,
        namespace: repo_namespace,
      },
    };

    local spec_with_target = if target_namespace != null then
      base_spec { targetNamespace: target_namespace }
    else
      base_spec;

    local final_spec = if patches != null then
      spec_with_target { patches: patches }
    else
      spec_with_target;

    {
      [kustomization_output]: {
        apiVersion: 'kustomize.toolkit.fluxcd.io/v1',
        kind: 'Kustomization',
        metadata: {
          name: name,
          namespace: namespace,
        },
        spec: final_spec,
      },
    },
}
