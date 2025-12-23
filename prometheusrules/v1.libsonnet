{
  resources(
    app_name,
    component_name,
    rule_name,
    namespace,
    cluster,
    alert,
    message,
    runbook_url,
    expression,
    duration,
    severity,
  )::

    local fmt_context = {
      app_name: app_name,
      component_name: component_name,
      rule_name: rule_name,
      namespace: namespace,
      cluster: cluster,

    };

    local output = '%(app_name)s-%(rule_name)s-prometheusrule.json' % fmt_context;
    local qualified_name = '%(app_name)s-%(rule_name)s' % fmt_context;

    {
      [output]: {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'PrometheusRule',
        metadata: {
          name: qualified_name,
          namespace: namespace,
          labels: {
            app: app_name,
          } + (
            if component_name != '' then
              { component: component_name }
            else
              {}
          ),
        },
        spec: {
          groups: [
            {
              name: qualified_name,
              rules: [
                {
                  alert: alert,
                  annotations: {
                    message: message,
                    runbook_url: runbook_url,
                  },
                  expr: expression,
                  'for': duration,
                  labels: {
                    app: app_name,
                    component: qualified_name,
                    severity: severity,
                  },
                },
              ],
            },
          ],
        },
      },
    },
}

//[prometheus_rule_output]: {
//  apiVersion: 'monitoring.coreos.com/v1',
//  kind: 'PrometheusRule',
//  metadata: {
//    name: prometheus_rule_name,
//    namespace: namespace_name,
//    labels: {
//      app: app_name,
//      component: deployment_name,
//    },
//  },
//  spec: {
//    groups: [
//      {
//        name: app_name,
//        rules: [
//          {
//            alert: prometheus_alert,
//            annotations: {
//              message: prometheus_message,
//            },
//            expr: prometheus_rule_expression,
//            'for': prometheus_duration,
//            labels: {
//              app: app_name,
//              component: deployment_name,
//              severity: prometheus_severity,
//            },
//          },
//        ],
//      },
//    ],
//  },
//},
