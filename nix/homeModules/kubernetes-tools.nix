{ inputs, ... }:

{
  flake.homeModules.kubernetes-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        kustomize
        kubernetes-helm
        minikube
        kompose
      ];
    };
}
