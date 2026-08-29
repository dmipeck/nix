# nix

Generic, reusable NixOS + home-manager module library. No hosts — only
`nixosModules`, `homeModules`, `vscodeModules`, `devShells`, consumed by
other flakes. `CLAUDE.md` is a symlink to `AGENTS.md`.

## Layout

Every file under `nix/` is auto-imported as a flake-parts module
(`inputs.import-tree ./nix`). Drop a file returning
`{ flake.<category>.<name> = ...; }`:

- `nix/nixosModules/` — NixOS modules
- `nix/homeModules/` — home-manager modules; `desktop/` = GUI apps
- `nix/homeModules/desktop/vscode/` — VS Code extension sets (`flake.vscodeModules`)
- `nix/devShells/` — dev shell

The module name is the option key, not the filename.

## Usage

Consume modules from another flake, e.g. `inputs.nix.nixosModules.desktop`
with `inputs.nix.url = "github:dmipeck/nix"`.

## Dev

- `nix flake check` — CI gate; lazily validates modules, doesn't build homeModules
- `nix develop` — devShell + pre-commit hooks (conventional commits, gitleaks)
