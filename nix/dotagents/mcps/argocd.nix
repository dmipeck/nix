{ lib, withSystem, ... }:
let
  # flake-parts flake modules get no `pkgs` argument (only perSystem does), so
  # reach into the x86_64-linux system's pkgs via withSystem, mirroring
  # nix/skills/ai-tools.nix. The package is a derivation; evaluation stays
  # lazy until a consumer forces it.
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
in
{
  options.dotagents.mcpPackages."argocd-mcp" = lib.mkOption {
    type = lib.types.package;
    description = "argocd-mcp MCP server package.";
  };

  config.dotagents.mcpPackages."argocd-mcp" = lib.mkDefault argocdMcp;

  config.dotagents.mcpServers.argocd = {
    type = "local";
    command = "${argocdMcp}/bin/argocd-mcp";
    args = [ "stdio" ];
    # API token and base URL are per-user placeholders; the consumer's
    # home-manager config wraps the server so the token is read from a
    # sops-decrypted file at startup (see dmipeck/nix homeModules/dotagents.nix).
    env = {
      MCP_READ_ONLY = "true";
      ARGOCD_BASE_URL = "";
      ARGOCD_API_TOKEN = "";
    };
    # Mirrors the "never make changes directly to the cluster" principle:
    # block create/update/delete/sync/run-action tools, leaving only
    # inspection. Cluster changes still flow through ./kustomize and ArgoCD.
    readOnlyTools = [
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
  };
}
