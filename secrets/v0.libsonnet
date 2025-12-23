local clusterrolebindings_v0 = import '../clusterrolebindings/v0.libsonnet';
local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';
local vaults_v0 = import '../vaults/v0.libsonnet';

{
  resources(
    aws_account_number,
    cluster,
    environment,
    namespace_name,
    service_account_name,
    secret_auth_name,
    secret_role_name,
    secret_refresh_period,
    secret_names,
  )::

    local secret_mount = if environment == 'int' then 'infra' else environment;

    // Service Account for pulling secrets.  Has nothing to do with SA's for apps.
    local service_account = serviceaccounts_v0.resources(
      name=service_account_name,
      namespace=namespace_name,
      aws_account_number=aws_account_number,
      iam_role_name=service_account_name,
    );

    local vault_auth = vaults_v0.auth_resources(
      name=secret_auth_name,
      namespace_name=namespace_name,
      cluster=cluster,
      role=secret_role_name,
      service_account_name=service_account_name,
    );

    // function to make vault secrets.  name, path, and secret_name are all the same
    local makeVaultSecret(name) = vaults_v0.secret_resources(
      name=name,
      namespace_name=namespace_name,
      cluster=cluster,
      auth_name=secret_auth_name,
      mount=secret_mount,
      path=name,
      secret_name=name,
      refresh=secret_refresh_period,
    );

    // create a vault secret for each name using the above function.
    local vault_secrets = std.foldl(function(acc, obj) acc + obj, std.map(function(name) makeVaultSecret(name), secret_names), {});

    local crb =
      clusterrolebindings_v0.resources(
        name=namespace_name,
        clusterrole_name='system:auth-delegator',
        subjects=[
          {
            kind: 'ServiceAccount',
            name: service_account_name,
            namespace: namespace_name,
          },
        ],
      );

    {}
    + crb
    + service_account
    + vault_auth
    + vault_secrets,
}
