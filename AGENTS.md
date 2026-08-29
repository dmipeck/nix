# Infra Repository — Agent Guide

## Core Principle: Everything is Declarative

This repository manages both NixOS machines and a Kubernetes cluster through declarative configuration. **Never make changes directly** — to a machine or to the cluster. All changes flow through this repository.

---

## Session Start: Worktree Check

Before doing any work, check whether the current directory is a git worktree rather than the main checkout:

```bash
git rev-parse --git-common-dir --git-dir
```

If the two paths differ, this is a worktree.

If working in a worktree:

1. **Open a PR/MR early.** Push the branch and create the PR (`gh pr create --draft`) as soon as there's a first commit to show — don't wait until the work is "done" to open it.
2. **Commit and push after each change**, not just at the end. Every discrete edit (a module added, a kustomization updated, a doc fix) should be its own commit, pushed immediately, so the PR reflects live progress rather than one large batched diff at the finish.

This does not change the rules below — never apply changes directly to a machine or the cluster. Commits and pushes drive changes through comin/ArgoCD exactly as described in [Applying Changes](#applying-changes), they just happen incrementally instead of all at once.

---

## The Dendritic Flake Pattern

[flake.nix](flake.nix) contains a single outputs line:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
```

`import-tree` recursively imports every `.nix` file under [./modules/](modules/), and `flake-parts` stitches them into a single coherent flake. This is the **dendritic pattern** — there is no central `configuration.nix` that lists everything. Each module registers itself. Adding a new module means dropping a file into the right subdirectory; nothing else needs to be wired up.

---

## Applying Changes

### Local machine (NixOS system config)

```bash
sudo nixos-rebuild switch --flake .
```

Replace `<hostname>` with the machine name defined under [./modules/hosts/](modules/hosts/) (e.g. `laptop`, `desktop`).

### Local machine (home-manager only)

```bash
home-manager switch --flake .
```

User configs live under [./modules/home/](modules/home/). Each user profile composes modules from [./modules/homeModules/](modules/homeModules/).

### Remote machines via comin

Remote hosts (loadbalancer and the three Kubernetes nodes) run [comin](https://github.com/nlewo/comin), a NixOS module that polls this repository and applies changes automatically. To deploy:

```bash
git push
```

comin detects the new commit, pulls it, and runs `nixos-rebuild` on the target machine. No SSH required for routine deploys. The comin input is pinned in [flake.nix](flake.nix) and the module is enabled per-host under [./modules/hosts/](modules/hosts/).

---

## Module Subdirectories

| Directory | Purpose |
|---|---|
| [modules/hosts/](modules/hosts/) | Per-machine NixOS entry points. Each host composes nixosModules and sets machine-specific values. |
| [modules/nixosModules/](modules/nixosModules/) | Reusable NixOS system-level modules. Add one here to make it available for any host to enable. |
| [modules/home/](modules/home/) | Per-user home-manager profiles. Each user entry point composes homeModules. |
| [modules/homeModules/](modules/homeModules/) | Reusable user-space modules for applications and shell tooling. Add one here to make it available for any user profile to enable. |
| [modules/devShells/](modules/devShells/) | Nix dev shells providing project tooling. Enter with `nix develop`. |
| [modules/packages/](modules/packages/) | Custom Nix package derivations not available upstream. |

---

## Kubernetes Cluster Changes — Kustomize Only

**Never run `kubectl apply`, `helm install`, or any imperative cluster command directly.** All cluster state is managed declaratively through kustomizations under [./kustomize/](kustomize/).

### How it works

Kustomizations under [./kustomize/](kustomize/) are applied to the cluster by ArgoCD (itself bootstrapped via a kustomization). To make a cluster change:

1. Edit or add files under [./kustomize/](kustomize/).
2. Commit and push.
3. ArgoCD detects the change and applies it.

For changes that need to be applied before ArgoCD is running (bootstrap), apply the kustomization manually once:

```bash
kubectl apply -k ./kustomize/<dir>
```

Then never touch it imperatively again.

### Current kustomizations

| Directory | What it deploys |
|---|---|
| [kustomize/argocd/](kustomize/argocd/) | ArgoCD with Keycloak OIDC authentication. Includes namespace, stable upstream manifest, and a ConfigMap patch for the base URL. |
| [kustomize/cilium/](kustomize/cilium/) | Cilium v1.19.5 CNI via Helm generator. VXLAN tunneling, cluster-pool IPAM, service topology enabled. |

### Adding a new workload

Create a new subdirectory under [./kustomize/](kustomize/) with a `kustomization.yaml`. Reference it from an ArgoCD `Application` manifest (also under [./kustomize/](kustomize/)). Push. Done.

### What never to do

- `kubectl edit` anything
- `helm upgrade` directly
- `kubectl delete` and re-create resources by hand
- Patch live resources with `kubectl patch`

If you find yourself wanting to do any of the above, write a kustomization patch instead.
