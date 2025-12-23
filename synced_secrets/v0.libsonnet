local clusterrolebindings_v0 = import '../clusterrolebindings/v0.libsonnet';
local obj_merge = import '../obj-merge.libsonnet';
local serviceaccounts_v0 = import '../serviceaccounts/v0.libsonnet';
local vault_auth_v0 = import '../vaults/auth-v0.libsonnet';
local vault_secret_v1 = import '../vaults/secret-v1.libsonnet';

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
    secrets,
  )::

    local secret_mount = if environment == 'int' then 'infra' else environment;

    // Service Account for pulling secrets.  Has nothing to do with SA's for apps.
    local service_account = serviceaccounts_v0.resources(
      name=service_account_name,
      namespace=namespace_name,
      aws_account_number=aws_account_number,
      iam_role_name=service_account_name,
    );

    local vault_auth = vault_auth_v0.resources(
      name=secret_auth_name,
      namespace_name=namespace_name,
      cluster=cluster,
      role=secret_role_name,
      service_account_name=service_account_name,
    );

    // function to make vault secrets.  name, path, and secret_name are all the same
    local makeVaultSecret(secret) = vault_secret_v1.resources(
      name=secret.name,
      namespace_name=namespace_name,
      cluster=cluster,
      auth_name=secret_auth_name,
      mount=secret_mount,
      path=secret.name,
      secret_name=secret.name,
      refresh=secret_refresh_period,
      restart_targets=secret.restart_targets,
    );

    // create a vault secret for each name using the above function.
    local vault_secrets = obj_merge.object_merge(std.map(function(secret) makeVaultSecret(secret), secrets));

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
