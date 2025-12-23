{
  resources(
    name,
    namespace,
    aws_account_number,
    aws_region,
    interval=null,
  )::
    local fmt_context = {
      name: name,
      aws_account_number: aws_account_number,
      aws_region: aws_region,
      namespace: namespace,

    };

    local repo_output = '%(name)s-imagerepo.json' % fmt_context;
    local image_repo = '%(aws_account_number)s.dkr.ecr.%(aws_region)s.amazonaws.com/%(name)s' % fmt_context;


    {
      [repo_output]: {
        apiVersion: 'image.toolkit.fluxcd.io/v1beta2',
        kind: 'ImageRepository',
        metadata: {
          name: name,
          namespace: namespace,
        },
        spec: {
          image: image_repo,
          interval: if interval != null then interval else '1m0s',
          provider: 'aws',
        },
      },
    },
}
