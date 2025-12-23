{
  resources(
    name,
    namespace_name,
    cluster,
    auth_name,
    mount,
    path,
    secret_name,
    refresh,  //30s
    restart_targets,
  )::
    local fmt_context = {
      name: name,
    };

    local flux_vault_secret_output = '%(name)s-vaultsecret.json' % fmt_context;

    {
      [flux_vault_secret_output]: {
        apiVersion: 'secrets.hashicorp.com/v1beta1',
        kind: 'VaultStaticSecret',
        metadata: {
          name: name,
          namespace: namespace_name,
        },
        spec: {
          destination: {
            create: true,
            name: secret_name,
          },
          mount: mount,
          path: path,
          refreshAfter: refresh,
          type: 'kv-v2',
          vaultAuthRef: auth_name,
          rolloutRestartTargets: restart_targets,
        },
      },
    },
}
