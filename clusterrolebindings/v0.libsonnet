{
  resources(
    name,
    clusterrole_name,
    subjects,
  )::
    local fmt_context = {
      name: name,
    };

    local cluster_rolebinding_output = '%(name)s-clusterrolebinding.json' % fmt_context;

    {
      [cluster_rolebinding_output]: {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'ClusterRoleBinding',
        metadata: {
          name: name,
        },
        roleRef: {
          apiGroup: 'rbac.authorization.k8s.io',
          kind: 'ClusterRole',
          name: clusterrole_name,
        },
        subjects: subjects,
      },
    },
}
