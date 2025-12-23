local imagerepos = import '../imagerepositories/v0.libsonnet';
local podmonitors = import '../podmonitors/v0.libsonnet';
local serviceaccounts = import '../serviceaccounts/v0.libsonnet';

{
  resources(
    aws_account_number,
    region,
    cluster,
    environment,
    namespace_name,
    app,
    command,
    image_prefix,
    image_repo_name,
    service_account_name,
    secret_name,
    env,
    envFrom,
    resources,
    replicas,
    flux
  )::

    local app_name = app;
    local fmt_context = {
      app: app,
      command: command,
      app_name: app_name,
      cluster: cluster,
      environment: environment,
      namespace_name: namespace_name,
      image_prefix: image_prefix,
    };


    local image = image_prefix + '/' + image_repo_name + ':latest';
    local deployment_output = '%(app_name)s-deployment.json' % fmt_context;
    local service_account = serviceaccounts.resources(
      name=service_account_name,
      namespace=namespace_name,
      aws_account_number=aws_account_number,
      iam_role_name=service_account_name,
    );

    local podmonitor = podmonitors.resources(
      app_name,
      namespace_name,
      [
        {
          targetPort: 8080,
        },
      ],
      {
        app: app_name,
      },
    );

    local imagerepository = if flux then imagerepos.resources(
      image_repo_name,
      namespace_name,
      aws_account_number,
      region,
    ) else {};

    {
      [deployment_output]: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: app_name,
          namespace: namespace_name,
          labels: {
            app: app_name,
          },
        },
        spec: {
          replicas: replicas,
          selector: {
            matchLabels: {
              app: app_name,
            },
          },
          strategy: {
            rollingUpdate: {
              maxSurge: 1,
              maxUnavailable: 1,
            },
            type: 'RollingUpdate',
          },
          template: {
            metadata: {
              labels: {
                app: app_name,
              },
            },
            spec: {
              serviceAccountName: service_account_name,
              containers: [
                {
                  name: app_name,
                  image: image,
                  imagePullPolicy: 'IfNotPresent',
                  command: command,
                  ports: [
                    {
                      name: 'http',
                      containerPort: 8080,
                      protocol: 'TCP',
                    },
                  ],
                  resources: resources,
                  env: env,
                  envFrom: envFrom,
                  readinessProbe: {
                    failureThreshold: 5,
                    httpGet: {
                      path: '/readyz',
                      port: 8080,
                    },
                    initialDelaySeconds: 10,
                    periodSeconds: 10,
                    successThreshold: 1,
                    timeoutSeconds: 5,
                  },
                  livenessProbe: {
                    failureThreshold: 5,
                    httpGet: {
                      path: '/healthz',
                      port: 8080,
                    },
                    initialDelaySeconds: 30,
                    periodSeconds: 10,
                    successThreshold: 1,
                    timeoutSeconds: 5,
                  },
                },
              ],
            },
          },
        },
      },
    }
    + podmonitor
    + service_account
    + imagerepository,
}
