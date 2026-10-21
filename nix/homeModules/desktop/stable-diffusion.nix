{ inputs, ... }:

{
  flake.homeModules.stable-diffusion =
    { pkgs, ... }:
    let
      system = pkgs.stdenv.hostPlatform.system;
    in
    {
      home.packages = [
        inputs.nixified-ai.packages.${system}.comfyui-nvidia
        inputs.self.packages.${system}.invokeai
      ];
    };
}
