{ lib, withSystem, ... }:
let
  pkgs = withSystem "x86_64-linux" ({ pkgs, ... }: pkgs);

  argocdMcp = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "argocd-mcp";
    version = "0.9.0";

    src = pkgs.fetchFromGitHub {
      owner = "argoproj-labs";
      repo = "mcp-for-argocd";
      rev = "v${finalAttrs.version}";
      hash = "sha256-D94APT+e/PRxZ3JQSvc2N3sTFjSvu3br1MybcnGVd14=";
    };

    nativeBuildInputs = [
      pkgs.nodejs
      pkgs.pnpm
      pkgs.pnpmConfigHook
      pkgs.makeWrapper
    ];

    pnpmDeps = pkgs.fetchPnpmDeps {
      inherit (finalAttrs) pname version src;
      pnpm = pkgs.pnpm;
      fetcherVersion = 4;
      hash = "sha256-Y/4rr3joxtG9VBNflv1YOGAKmxjx+AP69sVvFOiuQFU=";
    };

    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/argocd-mcp
      cp -r dist node_modules package.json $out/lib/argocd-mcp/
      makeWrapper ${pkgs.nodejs}/bin/node $out/bin/argocd-mcp \
        --add-flags $out/lib/argocd-mcp/dist/index.js
      runHook postInstall
    '';

    meta = {
      description = "MCP server for Argo CD";
      homepage = "https://github.com/argoproj-labs/mcp-for-argocd";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "argocd-mcp";
    };
  });

  readTools = [
    "list_clusters"
    "get_appproject"
    "list_applications"
    "get_application"
    "get_application_resource_tree"
    "get_application_managed_resources"
    "get_application_workload_logs"
    "get_resource_events"
    "get_resource_actions"
  ];
in
{
  config.dotagents.mcpPackages.argocd-mcp = lib.mkDefault argocdMcp;

  # Tool enum only — Server Definition is in authored mcp.json.
  config.dotagents.mcpServers.argocd = {
    _module.args.mcpToolEnum = lib.types.enum readTools;
    tools.read = readTools;
  };
}
