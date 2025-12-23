{
  auth_resources(
    name,
    namespace_name,
    cluster,
    role,
    service_account_name,
  )::
    local fmt_context = {
      name: name,
    };
    local vault_auth_output = '%(name)s-vaultauth.json' % fmt_context;

    {
      [vault_auth_output]: {
        apiVersion: 'secrets.hashicorp.com/v1beta1',
        kind: 'VaultAuth',
        metadata: {
          name: name,
          namespace: namespace_name,
        },
        spec: {
          kubernetes: {
            role: role,
            serviceAccount: service_account_name,
          },
          method: 'kubernetes',
          mount: cluster,
        },
      },
    },

  secret_resources(
    name,
    namespace_name,
    cluster,
    auth_name,
    mount,
    path,
    secret_name,
    refresh,  //30s
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
        },
      },
    },
}
