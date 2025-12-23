{
  resources(
    name,
    rules,
  )::

    local fmt_context = {
      name: name,

    };

    local role_output = '%(name)s-role.json' % fmt_context;

    {
      [role_output]: {
        apiVersion: 'rbac.authorization.k8s.io/v1',
        kind: 'ClusterRole',
        metadata: {
          name: name,
        },
        rules: rules,
      },
    },
}

//apiVersion: rbac.authorization.k8s.io/v1
//kind: ClusterRole
//metadata:
//  name: jobctl-system
//rules:
//  - apiGroups:
//      - ""
//      - batch
//    resources:
//      - cronjobs
//
//    verbs:
//      - get
//      - list
//      - watch
//
//  - apiGroups:
//      - ""
//      - batch
//
//    resources:
//      - jobs
//
//    verbs:
//      - get
//      - list
//      - watch
//      - create
