{
  inputs,
  lib,
  ...
}:

{
  flake.nixosModules.nvidia =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.nvidia = {
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = null;
          description = "NVIDIA driver package. Leave null to use the nixpkgs default for the kernel in use.";
        };
      };

      config = {
        # Make sure GUI programs (kwin, Xwayland, plasmashell, etc.) use the NVIDIA
        # GL/EGL implementation rather than Mesa.
        hardware.graphics = {
          enable = true;
        };

        hardware.nvidia = {
          # Modesetting is required.
          modesetting.enable = true;

          powerManagement.enable = false;
          powerManagement.finegrained = false;

          # Use the NVidia open source kernel module (not to be confused with the
          # third-party "nouveau" open source driver).
          open = false;

          # Enable the Nvidia settings menu,
          # accessible via `nvidia-settings`.
          nvidiaSettings = true;
        }
        // lib.optionalAttrs (config.nvidia.package != null) {
          package = config.nvidia.package;
        };

        # Load nvidia driver for Xorg and Wayland
        services.xserver.videoDrivers = [ "nvidia" ];

        systemd.services.display-manager = {
          wants = [ "nvidia-persistenced.service" ];
          after = [
            "systemd-user-sessions.service"
            "nvidia-persistenced.service"
            "multi-user.target"
          ];
        };

        boot.kernelParams = [
          "nvidia-drm.modeset=1"
        ];

        boot.initrd.kernelModules = [
          "nvidia"
          "nvidia_modeset"
          "nvidia_drm"
          "nvidia_uvm"
        ];

        boot.blacklistedKernelModules = [
          "nouveau"
        ];
      };
    };
}
