local promrules_v0 = import '../prometheusrules/v0.libsonnet';

{
  resources(
    name,
    namespace_name,
    app_name,
    component_name,
    cluster,
    image,
    start_command,
    resources,
    replicas,
    monitor_port,
    volumes,
    volume_mounts,
    env,
    env_from,
    health_path,
    readiness_path,
  )::

    local qualified_name = app_name + '-' + name;

    local fmt_context = {
      name: name,
      namespace_name: namespace_name,
      app_name: app_name,
      component_name: component_name,
      cluster: cluster,
      image: image,
      monitor_port: monitor_port,
      qualified_name: qualified_name,

    };

    local deploy_output = '%(qualified_name)s-deployment.json' % fmt_context;

    local promrule = promrules_v0.resources(
      app_name=app_name,
      component_name=name,
      rule_name=name,
      namespace=namespace_name,
      cluster=cluster,
      alert='%(qualified_name)s Down (%(cluster)s)' % fmt_context,
      message='%(qualified_name)s Down (%(cluster)s)' % fmt_context,
      expression='absent(kube_pod_container_info{namespace="%(namespace_name)s",pod=~"%(name)s.+" })' % fmt_context,
      duration='5m',
      severity='critical',
    );

    {
      [deploy_output]: {
        apiVersion: 'apps/v1',
        kind: 'Deployment',
        metadata: {
          name: name,
          labels: {
            app: app_name,
            component: component_name,
          },
          namespace: namespace_name,
        },
        spec: {
          replicas: replicas,
          strategy: {
            type: 'RollingUpdate',
            rollingUpdate: {
              maxUnavailable: 1,
              maxSurge: 2,
            },
          },
          selector: {
            matchLabels: {
              app: app_name,
              component: component_name,
            },
          },
          template: {
            metadata: {
              labels: {
                app: app_name,
                component: component_name,
              },
            },
            spec: {
              serviceAccountName: app_name,
              enableServiceLinks: false,
              containers: [
                {
                  image: image,
                  imagePullPolicy: 'IfNotPresent',
                  name: name,
                  command: start_command,
                  livenessProbe: {
                    httpGet: {
                      path: health_path,
                      port: monitor_port,
                    },
                    timeoutSeconds: 60,
                    initialDelaySeconds: 10,
                  },
                  readinessProbe: {
                    httpGet: {
                      path: readiness_path,
                      port: monitor_port,
                    },
                    timeoutSeconds: 60,
                    initialDelaySeconds: 10,
                  },
                  resources: resources,
                  volumeMounts: volume_mounts,
                  env: env,
                  envFrom: env_from,
                  ports: [
                    {
                      containerPort: monitor_port,
                    },
                  ],
                },
              ],
              volumes: volumes,
            },
          },
        },
      },
      //      [autoscaler_output]: {
      //        apiVersion: 'autoscaling/v2',
      //        kind: 'HorizontalPodAutoscaler',
      //        metadata: {
      //          name: deployment_name,
      //          namespace: namespace_name,
      //        },
      //        spec: {
      //          scaleTargetRef: {
      //            apiVersion: 'apps/v1',
      //            kind: 'Deployment',
      //            name: deployment_name,
      //          },
      //          minReplicas: 1,
      //          maxReplicas: 10,
      //          metrics: [{
      //            type: 'Resource',
      //            resource: {
      //              name: 'cpu',
      //              target: {
      //                type: 'Utilization',
      //                averageUtilization: 90,
      //              },
      //            },
      //          }],
      //        },
      //      },
    }
    + promrule,
}
