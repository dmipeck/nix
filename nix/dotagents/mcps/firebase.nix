{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring the
  # skills modules. The package is a nixpkgs derivation; evaluation stays lazy
  # until a consumer forces it.
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  # Tool names from firebase-tools' MCP server
  # (https://github.com/firebase/firebase-tools/blob/master/src/mcp/README.md).
  # The server auto-discovers feature groups from firebase.json / enabled APIs;
  # the enum here is the full published set so allowlists stay valid regardless
  # of which features a given project activates.
  readTools = [
    "apphosting_fetch_logs"
    "apphosting_list_backends"
    "auth_get_users"
    "crashlytics_batch_get_events"
    "crashlytics_get_issue"
    "crashlytics_get_report"
    "crashlytics_list_events"
    "crashlytics_list_notes"
    "dataconnect_build"
    "dataconnect_list_services"
    "firebase_get_environment"
    "firebase_get_project"
    "firebase_get_sdk_config"
    "firebase_get_security_rules"
    "firebase_list_apps"
    "firebase_list_projects"
    "firebase_read_resources"
    "firebase_validate_security_rules"
    "firestore_get_documents"
    "firestore_list_collections"
    "firestore_query_collection"
    "functions_get_logs"
    "functions_list_functions"
    "realtimedatabase_get_data"
    "remoteconfig_get_template"
    "storage_get_object_download_url"
  ];
  writeTools = [
    "auth_set_sms_region_policy"
    "auth_update_user"
    "crashlytics_create_note"
    "crashlytics_delete_note"
    "crashlytics_update_issue"
    "dataconnect_execute"
    "firebase_create_android_sha"
    "firebase_create_app"
    "firebase_create_project"
    "firebase_init"
    "firebase_login"
    "firebase_logout"
    "firebase_update_environment"
    "firestore_delete_document"
    "messaging_send_message"
    "realtimedatabase_set_data"
    "remoteconfig_update_template"
  ];
in
{
  # Official Firebase MCP server shipped inside firebase-tools
  # (`firebase mcp`). Local stdio transport; authenticates with the same
  # Firebase CLI credentials as `firebase login` in the environment where
  # the server runs — no sops token. Feature discovery is automatic unless
  # the consumer passes --only / --dir via args overrides.
  config.dotagents.mcpServers.firebase = {
    type = "local";
    command = "${pkgs.firebase-tools}/bin/firebase";
    args = [ "mcp" ];
    _module.args.mcpToolEnum = lib.types.enum (readTools ++ writeTools);
    tools.read = readTools;
    tools.write = writeTools;
  };
}
