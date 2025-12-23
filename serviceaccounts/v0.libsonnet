{
  resources(
    name,
    namespace,
    aws_account_number,
    iam_role_name,
  )::
    local fmt_context = {
      name: name,
      aws_account_number: aws_account_number,
      namespace: namespace,
      iam_role_name: iam_role_name,

    };

    local sa_output = '%(name)s-serviceaccount.json' % fmt_context;
    local role_annotation_value = 'arn:aws:iam::%(aws_account_number)s:role/%(iam_role_name)s' % fmt_context;

    {
      [sa_output]: {
        apiVersion: 'v1',
        kind: 'ServiceAccount',
        metadata: {
          name: name,
          namespace: namespace,
          annotations: {
            'eks.amazonaws.com/role-arn': role_annotation_value,
          },
        },
      },
    },
}
