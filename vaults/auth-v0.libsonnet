{
  resources(
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
}
