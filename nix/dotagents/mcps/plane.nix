{ lib, ... }:
let
  # The official Plane MCP server (Python plane-mcp-server) exposes 30
  # consolidated tools, one per resource, each taking an `action` parameter
  # that selects the operation (list/retrieve/create/update/delete/...). The
  # server is self-hosted at mcp.plane.littlemonkey.co.nz (PAT transport at
  # /http/api-key/mcp) and authenticates with a Plane API PAT sent as an
  # Authorization: Bearer header (wired
  # per-user via the home-manager overlay, see nix/homeModules/dotagents.nix
  # — this file never sees the token).
  planeTools = [
    "collection"
    "customer"
    "customer_property"
    "customer_request"
    "cycle"
    "get_pql_reference"
    "initiative"
    "intake"
    "label"
    "member"
    "milestone"
    "module"
    "page"
    "project"
    "project_estimate"
    "release"
    "release_label"
    "release_tag"
    "state"
    "template"
    "work_log"
    "workitem"
    "workitem_activity"
    "workitem_attachment"
    "workitem_comment"
    "workitem_link"
    "workitem_property"
    "workitem_relation"
    "workitem_type"
    "workspace"
  ];
in
{
  config.dotagents.mcpServers.plane = {
    type = "remote";
    url = "https://mcp.plane.littlemonkey.co.nz/http/api-key/mcp";
    # Every consolidated tool carries mutating actions (create/update/delete/
    # archive/manage/...), so the whole set is treated as write: the agent
    # asks before any Plane operation runs.
    _module.args.mcpToolEnum = lib.types.enum planeTools;
    tools.write = planeTools;
  };
}
