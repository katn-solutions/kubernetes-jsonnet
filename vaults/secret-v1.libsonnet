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
    type=null,
  )::
    local fmt_context = {
      name: name,
    };

    local flux_vault_secret_output = '%(name)s-vaultsecret.json' % fmt_context;

    local is_pg_role = std.startsWith(name, 'pg-role-');

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
            type: if type != null then type else 'Opaque',
          } + (if is_pg_role then {
                 labels: {
                   'cnpg.io/reload': 'true',
                 },
               } else {}),
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
