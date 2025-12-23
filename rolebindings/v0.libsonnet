{
  resources(
    name,
    namespace,
    role_name,
    service_account_name,
    service_account_namespace,
  )::
    local fmt_context = {
      name: name,
      namespace: namespace,

    };

    local rolebinding_output = '%(name)s-rolebinding.json' % fmt_context;

    {
      [rolebinding_output]: {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'RoleBinding',
        metadata: {
          name: name,
          namespace: namespace,
        },
        roleRef: {
          kind: 'Role',
          name: role_name,
          apiGroup: 'rbac.authorization.k8s.io',
        },
        subjects: [
          {
            kind: 'ServiceAccount',
            name: service_account_name,
            namespace: service_account_namespace,
          },
        ],
      },
    },
}
