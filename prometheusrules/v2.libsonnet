{
  resources(
    app_name,
    component_name,
    namespace,
    rule_groups,
  )::

    local fmt_context = {
      app_name: app_name,
      component_name: component_name,
      namespace: namespace,
    };

    local output = '%(app_name)s-prometheusrule.json' % fmt_context;
    local qualified_name = '%(app_name)s-alerts' % fmt_context;

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
          groups: rule_groups,
        },
      },
    },
}
