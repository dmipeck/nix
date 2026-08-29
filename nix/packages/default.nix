{ ... }:

{
  flake.overlays.build13 = final: prev: {
    argocd-mcp = final.stdenv.mkDerivation (finalAttrs: {
      pname = "argocd-mcp";
      version = "0.9.0";

      src = final.fetchFromGitHub {
        owner = "argoproj-labs";
        repo = "mcp-for-argocd";
        rev = "v${finalAttrs.version}";
        hash = "sha256-D94APT+e/PRxZ3JQSvc2N3sTFjSvu3br1MybcnGVd14=";
      };

      nativeBuildInputs = [
        final.nodejs
        final.pnpm
        final.pnpmConfigHook
        final.makeWrapper
      ];

      pnpmDeps = final.fetchPnpmDeps {
        inherit (finalAttrs) pname version src;
        pnpm = final.pnpm;
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
        makeWrapper ${final.nodejs}/bin/node $out/bin/argocd-mcp \
          --add-flags $out/lib/argocd-mcp/dist/index.js
        runHook postInstall
      '';

      meta = {
        description = "MCP server for Argo CD";
        homepage = "https://github.com/argoproj-labs/mcp-for-argocd";
        license = final.lib.licenses.asl20;
        mainProgram = "argocd-mcp";
      };
    });
  };
}
