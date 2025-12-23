// Hasura Operator CRD factory
// Generates HasuraInstance custom resources for declarative Hasura management
// API version: hasura.example.com/v1alpha1 (customize for your domain)

{
  // Main factory function to create a HasuraInstance CRD
  resources(
    name,
    namespace,
    version,
    endpoint,
    admin_secret_ref,
    database_url_ref,
    datasources=[],
    api_limits=null,
    introspection_config=null,
    reconcile_interval='5m',
  )::
    local hasura_instance_output = '%s-hasura.json' % name;

    {
      [hasura_instance_output]: {
        apiVersion: 'hasura.example.com/v1alpha1',
        kind: 'HasuraInstance',
        metadata: {
          name: '%s-hasura' % name,
          namespace: namespace,
        },
        spec: {
          version: version,
          endpoint: endpoint,
          adminSecretRef: {
            name: admin_secret_ref.name,
            key: admin_secret_ref.key,
          },
          reconcileInterval: reconcile_interval,
        } + (
          if api_limits != null then {
            apiLimits: api_limits,
          } else {}
        ) + (
          if introspection_config != null then {
            introspectionConfig: introspection_config,
          } else {}
        ) + (
          if std.length(datasources) > 0 then {
            dataSources: datasources,
          } else {
            dataSources: [
              {
                name: 'default',
                type: 'postgres',
                configuration: {
                  databaseURLRef: {
                    name: database_url_ref.name,
                    key: database_url_ref.key,
                  },
                  poolSettings: {
                    maxConnections: 50,
                    idleTimeout: 180,
                    retries: 1,
                    poolTimeout: 360,
                    connectionLifetime: 600,
                  },
                  usePreparedStatements: true,
                  isolationLevel: 'read-committed',
                },
                tables: [],
              },
            ],
          }
        ),
      },
    },

  // Helper function to create API limits configuration
  api_limits(
    depth_limit_global=10,
    depth_limit_per_role={},
    node_limit_global=100,
    node_limit_per_role={},
    batch_limit_global=5,
    batch_limit_per_role={},
    rate_limit_global={},
    rate_limit_per_role={},
    time_limit_global=10,
    time_limit_per_role={},
  )::
    {
      depthLimit: {
        global: depth_limit_global,
      } + (
        if std.length(depth_limit_per_role) > 0 then {
          perRole: depth_limit_per_role,
        } else {}
      ),
      nodeLimit: {
        global: node_limit_global,
      } + (
        if std.length(node_limit_per_role) > 0 then {
          perRole: node_limit_per_role,
        } else {}
      ),
    } + (
      if batch_limit_global != null || std.length(batch_limit_per_role) > 0 then {
        batchLimit: {
          global: batch_limit_global,
        } + (
          if std.length(batch_limit_per_role) > 0 then {
            perRole: batch_limit_per_role,
          } else {}
        ),
      } else {}
    ) + (
      if std.length(rate_limit_global) > 0 || std.length(rate_limit_per_role) > 0 then {
        rateLimit: (
          if std.length(rate_limit_global) > 0 then {
            global: rate_limit_global,
          } else {}
        ) + (
          if std.length(rate_limit_per_role) > 0 then {
            perRole: rate_limit_per_role,
          } else {}
        ),
      } else {}
    ) + (
      if time_limit_global != null || std.length(time_limit_per_role) > 0 then {
        timeLimit: {
          global: time_limit_global,
        } + (
          if std.length(time_limit_per_role) > 0 then {
            perRole: time_limit_per_role,
          } else {}
        ),
      } else {}
    ),

  // Helper function to create introspection configuration
  introspection_config(
    disabled_for_roles=[],
  )::
    {
      disabledForRoles: disabled_for_roles,
    },

  // Helper function to create a data source with tables
  datasource(
    name,
    database_url_ref,
    tables=[],
    pool_settings=null,
    use_prepared_statements=true,
    isolation_level='read-committed',
  )::
    {
      name: name,
      type: 'postgres',
      configuration: {
        databaseURLRef: {
          name: database_url_ref.name,
          key: database_url_ref.key,
        },
        usePreparedStatements: use_prepared_statements,
        isolationLevel: isolation_level,
      } + (
        if pool_settings != null then {
          poolSettings: pool_settings,
        } else {
          poolSettings: {
            maxConnections: 50,
            idleTimeout: 180,
            retries: 1,
            poolTimeout: 360,
            connectionLifetime: 600,
          },
        }
      ),
      tables: tables,
    },

  // Helper function to create pool settings
  pool_settings(
    max_connections=50,
    idle_timeout=180,
    retries=1,
    pool_timeout=360,
    connection_lifetime=600,
  )::
    {
      maxConnections: max_connections,
      idleTimeout: idle_timeout,
      retries: retries,
      poolTimeout: pool_timeout,
      connectionLifetime: connection_lifetime,
    },

  // Helper function to create a table configuration
  table(
    schema,
    name,
    select_permissions=[],
    insert_permissions=[],
    update_permissions=[],
    delete_permissions=[],
    object_relationships=[],
    array_relationships=[],
  )::
    {
      schema: schema,
      name: name,
    } + (
      if std.length(select_permissions) > 0 then {
        selectPermissions: select_permissions,
      } else {}
    ) + (
      if std.length(insert_permissions) > 0 then {
        insertPermissions: insert_permissions,
      } else {}
    ) + (
      if std.length(update_permissions) > 0 then {
        updatePermissions: update_permissions,
      } else {}
    ) + (
      if std.length(delete_permissions) > 0 then {
        deletePermissions: delete_permissions,
      } else {}
    ) + (
      if std.length(object_relationships) > 0 then {
        objectRelationships: object_relationships,
      } else {}
    ) + (
      if std.length(array_relationships) > 0 then {
        arrayRelationships: array_relationships,
      } else {}
    ),

  // Helper function to create a permission
  permission(
    role,
    columns=[],
    filter={},
    check=null,
    allow_aggregations=false,
    set=null,
    limit=null,
  )::
    {
      role: role,
    } + (
      if std.length(columns) > 0 then {
        columns: columns,
      } else {}
    ) + (
      if std.length(filter) > 0 then {
        filter: filter,
      } else {}
    ) + (
      if check != null then {
        check: check,
      } else {}
    ) + (
      if allow_aggregations then {
        allowAggregations: true,
      } else {}
    ) + (
      if set != null then {
        set: set,
      } else {}
    ) + (
      if limit != null then {
        limit: limit,
      } else {}
    ),

  // Helper function to create an object relationship (many-to-one)
  object_relationship(
    name,
    using_column,
  )::
    {
      name: name,
      using: {
        foreignKeyConstraintOn: using_column,
      },
    },

  // Helper function to create an object relationship with manual configuration
  object_relationship_manual(
    name,
    column_mapping,
    remote_schema,
    remote_table,
  )::
    {
      name: name,
      using: {
        manualConfiguration: {
          columnMapping: column_mapping,
          remoteTable: {
            schema: remote_schema,
            name: remote_table,
          },
        },
      },
    },

  // Helper function to create an array relationship (one-to-many)
  array_relationship(
    name,
    using_schema,
    using_table,
    using_column,
  )::
    {
      name: name,
      using: {
        foreignKeyConstraintOn: {
          table: {
            schema: using_schema,
            name: using_table,
          },
          column: using_column,
        },
      },
    },

  // Helper function to create an array relationship with manual configuration
  array_relationship_manual(
    name,
    column_mapping,
    remote_schema,
    remote_table,
  )::
    {
      name: name,
      using: {
        manualConfiguration: {
          columnMapping: column_mapping,
          remoteTable: {
            schema: remote_schema,
            name: remote_table,
          },
        },
      },
    },
}
