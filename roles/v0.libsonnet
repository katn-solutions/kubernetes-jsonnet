{
  resources(name, namespace, rules)::
    local fmt_context = {
      name: name,
      namespace: namespace,

    };

    local role_output = '%(name)s-role.json' % fmt_context;

    {
      [role_output]: {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'Role',
        metadata: {
          name: name,
          namespace: namespace,
        },
        rules: rules,
      },
    },
}

//---
//kind: Role
//apiVersion: rbac.authorization.k8s.io/v1
//metadata:
//  name: k8s-commander
//  namespace: napa
//rules:
//  - apiGroups:
//      - ""
//
//    resources:
//      - pods
//
//    verbs:
//      - get
//      - list
//      - watch
//      - delete
