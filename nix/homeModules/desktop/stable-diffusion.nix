# Stable Diffusion UIs from nixified.ai (NVIDIA).
# ComfyUI: https://github.com/nixified-ai/flake (current)
# InvokeAI: unmaintained — pinned last working rev (see flake input nixified-ai-invokeai)
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
        inputs.nixified-ai-invokeai.packages.${system}.invokeai-nvidia
      ];
    };
}
