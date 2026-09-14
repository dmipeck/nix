{ lib, ... }:
let
  cloudflareReadTools = [
    "docs"
    "search"
  ];
  cloudflareWriteTools = [
    "execute"
  ];
  bindingsReadTools = [
    "kv_namespaces_list"
    "kv_namespace_get"
    "workers_list"
    "workers_get_worker"
    "workers_get_worker_code"
    "r2_buckets_list"
    "r2_bucket_get"
    "d1_databases_list"
    "d1_database_get"
    "hyperdrive_configs_list"
    "hyperdrive_configs_get"
  ];
  bindingsWriteTools = [
    "kv_namespace_create"
    "kv_namespace_delete"
    "kv_namespace_update"
    "r2_bucket_create"
    "r2_bucket_delete"
    "d1_database_create"
    "d1_database_delete"
    "d1_database_query"
    "hyperdrive_configs_create"
    "hyperdrive_configs_delete"
    "hyperdrive_configs_edit"
  ];
  observabilityReadTools = [
    "query_worker_observability"
    "observability_keys"
    "observability_values"
  ];
in
{
  # Tool enums only — Server Definitions (urls) live in authored mcp.json.
  # Instance overlays wire Authorization headers via sops in homeModules.
  config.dotagents.mcpServers = {
    cloudflare = {
      _module.args.mcpToolEnum = lib.types.enum (cloudflareReadTools ++ cloudflareWriteTools);
      tools.read = cloudflareReadTools;
      tools.write = cloudflareWriteTools;
    };
    "cloudflare-bindings" = {
      _module.args.mcpToolEnum = lib.types.enum (bindingsReadTools ++ bindingsWriteTools);
      tools.read = bindingsReadTools;
      tools.write = bindingsWriteTools;
    };
    "cloudflare-observability" = {
      _module.args.mcpToolEnum = lib.types.enum observabilityReadTools;
      tools.read = observabilityReadTools;
    };
  };
}
