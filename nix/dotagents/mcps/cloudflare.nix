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
  # Cloudflare's managed MCP servers (stateless streamable HTTP at /mcp,
  # documented at developers.cloudflare.com/agents/model-context-protocol/
  # cloudflare/servers-for-cloudflare/). All three authenticate the same way:
  # interactive OAuth 2.1, or an API token sent as an Authorization: Bearer
  # header (wired per-user via the home-manager overlay, see
  # nix/homeModules/dotagents.nix — this file never sees the token). What an
  # API token may do is fixed at token creation: a read-only token yields a
  # read-only agent. Account-scoped tokens need the "Account Resources: Read"
  # permission so the server can auto-detect the account ID; tokens with
  # Client IP Address Filtering are not supported.
  config.dotagents.mcpServers = {
    # Code Mode server — full programmatic control over the whole Cloudflare
    # API (~2,500 endpoints) through three tools: docs (search developer
    # docs), search (query the OpenAPI spec) and execute (run JavaScript
    # against cloudflare.request()).
    cloudflare = {
      type = "remote";
      url = "https://mcp.cloudflare.com/mcp";
      _module.args.mcpToolEnum = lib.types.enum (cloudflareReadTools ++ cloudflareWriteTools);
      tools.read = cloudflareReadTools;
      tools.write = cloudflareWriteTools;
    };
    # Workers Bindings server — discrete per-resource tools over KV
    # namespaces, Workers, R2 buckets, D1 databases and Hyperdrive configs.
    # Read tools (list/get) are allow-listed; create/delete/update/query are
    # explicit ask/prompt candidates.
    "cloudflare-bindings" = {
      type = "remote";
      url = "https://bindings.mcp.cloudflare.com/mcp";
      _module.args.mcpToolEnum = lib.types.enum (bindingsReadTools ++ bindingsWriteTools);
      tools.read = bindingsReadTools;
      tools.write = bindingsWriteTools;
    };
    # Observability server — worker logs, metrics and schema discovery
    # queries. Entirely read-only.
    "cloudflare-observability" = {
      type = "remote";
      url = "https://observability.mcp.cloudflare.com/mcp";
      _module.args.mcpToolEnum = lib.types.enum observabilityReadTools;
      tools.read = observabilityReadTools;
    };
  };
}
