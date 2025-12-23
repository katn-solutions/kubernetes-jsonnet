/*
  Expects optional 'resources' input as map in the form:
    requests: {
      cpu: '1m',
      memory: '8Mi',
    },
    limits: {
      cpu: '10m',
      memory: '16Mi',
    },
*/
{
  vpa_resources(namespace, name, targetApi, targetKind, updateMode, resources)::
    local fmt_context = {
      name: name,
      namespace: namespace,
    };

    local vpa_output = '%(namespace)s-%(name)s-vpa.json' % fmt_context;
    {} + if resources != null then
      {
        [vpa_output]: {
          apiVersion: 'autoscaling.k8s.io/v1',
          kind: 'VerticalPodAutoscaler',
          metadata: {
            name: name,
            namespace: namespace,
          },
          spec: {
            targetRef: {
              apiVersion: targetApi,
              kind: targetKind,
              name: name,
            },
            updatePolicy: {
              updateMode: updateMode,
            },
            resourcePolicy: {
              containerPolicies: [
                {
                  containerName: '*',
                  minAllowed: {
                    cpu: resources.requests.cpu,
                    memory: resources.requests.memory,
                  },
                  maxAllowed: {
                    cpu: resources.limits.cpu,
                    memory: resources.limits.memory,
                  },
                },
              ],
            },
          },
        },
      }
    else
      {
        [vpa_output]: {
          apiVersion: 'autoscaling.k8s.io/v1',
          kind: 'VerticalPodAutoscaler',
          metadata: {
            name: name,
            namespace: namespace,
          },
          spec: {
            targetRef: {
              apiVersion: targetApi,
              kind: targetKind,
              name: name,
            },
            updatePolicy: {
              updateMode: updateMode,
            },
          },
        },
      },
}
{
  deployment_vpa_resources(name, namespace, updateMode, resources)::
    local fmt_context = {
      name: name,
      namespace: namespace,
    };

    local vpa_output = '%(namespace)s-%(name)s-vpa.json' % fmt_context;

    {} + if resources != null then
      {
        [vpa_output]: {
          apiVersion: 'autoscaling.k8s.io/v1',
          kind: 'VerticalPodAutoscaler',
          metadata: {
            name: name,
            namespace: namespace,
          },
          spec: {
            targetRef: {
              apiVersion: 'apps/v1',
              kind: 'Deployment',
              name: name,
            },
            updatePolicy: {
              updateMode: updateMode,
            },
            resourcePolicy: {
              containerPolicies: [
                {
                  containerName: '*',
                  minAllowed: {
                    cpu: resources.requests.cpu,
                    memory: resources.requests.memory,
                  },
                  maxAllowed: {
                    cpu: resources.limits.cpu,
                    memory: resources.limits.memory,
                  },
                },
              ],
            },
          },
        },

      }
    else
      {
        [vpa_output]: {
          apiVersion: 'autoscaling.k8s.io/v1',
          kind: 'VerticalPodAutoscaler',
          metadata: {
            name: name,
            namespace: namespace,
          },
          spec: {
            targetRef: {
              apiVersion: 'apps/v1',
              kind: 'Deployment',
              name: name,
            },
            updatePolicy: {
              updateMode: updateMode,
            },
          },
        },

      },

}
{
  sts_vpa_resources(name, namespace, updateMode, resources)::
    local fmt_context = {
      name: name,
      namespace: namespace,
    };

    local vpa_output = '%(namespace)s-%(name)s-vpa.json' % fmt_context;

    {} + if resources != null then
      {
        [vpa_output]: {
          apiVersion: 'autoscaling.k8s.io/v1',
          kind: 'VerticalPodAutoscaler',
          metadata: {
            name: name,
            namespace: namespace,
          },
          spec: {
            targetRef: {
              apiVersion: 'apps/v1',
              kind: 'StatefulSet',
              name: name,
            },
            updatePolicy: {
              updateMode: updateMode,
            },
            resourcePolicy: {
              containerPolicies: [
                {
                  containerName: '*',
                  minAllowed: {
                    cpu: resources.requests.cpu,
                    memory: resources.requests.memory,
                  },
                  maxAllowed: {
                    cpu: resources.limits.cpu,
                    memory: resources.limits.memory,
                  },
                },
              ],
            },
          },
        },
      }
    else
      {
        [vpa_output]: {
          apiVersion: 'autoscaling.k8s.io/v1',
          kind: 'VerticalPodAutoscaler',
          metadata: {
            name: name,
            namespace: namespace,
          },
          spec: {
            targetRef: {
              apiVersion: 'apps/v1',
              kind: 'StatefulSet',
              name: name,
            },
            updatePolicy: {
              updateMode: updateMode,
            },
          },
        },
      },
}
