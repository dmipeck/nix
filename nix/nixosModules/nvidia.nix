{ inputs, ... }:

{
  flake.nixosModules.nvidia =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      # Make sure GUI programs (kwin, Xwayland, plasmashell, etc.) use the NVIDIA
      # GL/EGL implementation rather than Mesa.
      hardware.graphics = {
        enable = true;
      };

      hardware.nvidia = {

        package = config.boot.kernelPackages.nvidiaPackages.legacy_580;

        # Modesetting is required.
        modesetting.enable = true;

        powerManagement.enable = false;
        powerManagement.finegrained = false;

        # Use the NVidia open source kernel module (not to be confused with the
        # independent third-party "nouveau" open source driver).
        # Support is limited to the Turing and later architectures. Full list of
        # supported GPUs is at:
        # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
        # Only available from driver 515.43.04+
        open = false;

        # Enable the Nvidia settings menu,
        # accessible via `nvidia-settings`.
        nvidiaSettings = true;
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
}
