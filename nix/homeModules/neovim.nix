{ inputs, ... }:

{
  flake.homeModules.neovim =
    { pkgs, ... }:
    {
      imports = [ inputs.nixvim.homeModules.nixvim ];

      programs.nixvim = {
        enable = true;
        viAlias = true;
        vimAlias = true;

        # Reuse home-manager's own pkgs (with our overlays/config already
        # applied) instead of letting nixvim import its own pinned nixpkgs.
        nixpkgs.pkgs = pkgs;

        colorschemes.rose-pine.enable = true;

        opts = {
          number = true;
          relativenumber = true;
          expandtab = true;
          shiftwidth = 2;
          tabstop = 2;
        };

        # Disable netrw in favour of nvim-tree.
        globals = {
          loaded_netrw = 1;
          loaded_netrwPlugin = 1;
        };

        plugins.nvim-tree = {
          enable = true;
          openOnSetup = false;
          openOnSetupFile = false;
        };

        plugins.treesitter = {
          enable = true;
          highlight.enable = true;
          indent.enable = true;
        };

        # Schema-based validation/completion for JSON and YAML (k8s,
        # kustomize, GH Actions, package.json, tsconfig, etc.), wired
        # automatically into jsonls/yamlls below.
        plugins.schemastore = {
          enable = true;
          json.enable = true;
          yaml.enable = true;
        };

        plugins.lsp.servers = {
          gopls.enable = true;
          rust_analyzer = {
            enable = true;
            installCargo = false;
            installRustc = false;
          };
          jsonls.enable = true;
          yamlls.enable = true;
          nixd.enable = true;
          # Docker's own unified LSP — covers Dockerfiles, Compose files, and
          # Bake files — superseding the older split dockerls /
          # docker_compose_language_service servers.
          docker_language_server.enable = true;
        };
      };

      home.sessionVariables = {
        EDITOR = "nvim";
      };
    };

}
