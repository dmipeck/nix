{ lib, ... }:
let
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
  # Tool enum only — url/headers from mcp.json + Instance overlay.
  config.dotagents.mcpServers.plane = {
    _module.args.mcpToolEnum = lib.types.enum planeTools;
    tools.write = planeTools;
  };
}
