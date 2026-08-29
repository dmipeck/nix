{ inputs, ... }:

{
  flake.nixosModules.kubernetes =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      cfg = config.kubernetesNode;
      api = "https://${cfg.masterHostname}:${toString cfg.masterPort}";
    in
    {
      options.kubernetesNode = {
        enable = lib.mkEnableOption "Kubernetes cluster member";
        localIP = lib.mkOption {
          type = lib.types.str;
          description = "The node's local IP address for Kubernetes proxy binding";
        };
        masterHostname = lib.mkOption {
          type = lib.types.str;
          description = "Hostname of the Kubernetes API server";
        };
        masterPort = lib.mkOption {
          type = lib.types.port;
          default = 6443;
          description = "Port of the Kubernetes API server";
        };
        master = {
          enable = lib.mkEnableOption "Kubernetes master role";
          caOrganisation = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Organisation name for the Kubernetes CA certificate";
          };
          adminKubeconfigPath = lib.mkOption {
            type = lib.types.str;
            default = "kubernetes/admin.conf";
            description = "Path for the cluster admin kubeconfig, relative to /etc";
          };
          additionalSANs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "Additional SANs for the API server certificate";
          };
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelModules = [ "ceph" ];

        networking.firewall = {
          allowedTCPPorts = [
            2379 # etcd-client
            2380 # etcd-cluster
            6443 # kube-apiserver
            4240 # cilium health
            10250
            10254
          ];
          allowedUDPPorts = [
            8472 # cilium VXLAN
          ];
        };

        environment.systemPackages = with pkgs; [
          kubectl
          kubernetes
        ];

        services.kubernetes = {
          roles =
            if cfg.master.enable then
              [
                "master"
                "node"
              ]
            else
              [ "node" ];
          masterAddress = cfg.masterHostname;
          apiserverAddress = api;
          easyCerts = true;

          proxy = {
            enable = true;
            bindAddress = cfg.localIP;
          };

          kubelet = {
            kubeconfig.server = api;
            nodeIp = cfg.localIP;
          };

          flannel.enable = false;
          addons.dns = {
            enable = true;
            corefile = ''
              .:10053 {
                errors
                health :10054
                kubernetes cluster.local in-addr.arpa ip6.arpa {
                  pods insecure
                  fallthrough in-addr.arpa ip6.arpa
                }
                prometheus :10055
                forward . ${lib.concatStringsSep " " config.clusterNetworking.nameservers}
                cache 30
                loop
                reload
                loadbalance
              }
            '';
          };
        }
        // lib.optionalAttrs cfg.master.enable {
          apiserver = {
            securePort = cfg.masterPort;
            advertiseAddress = cfg.localIP;
            allowPrivileged = true;
            extraSANs = [ cfg.masterHostname ] ++ cfg.master.additionalSANs;
          };
          pki = {
            enable = true;
            caSpec = {
              CN = cfg.masterHostname;
              O = cfg.master.caOrganisation;
              OU = cfg.masterHostname;
            };
            cfsslAPIExtraSANs = [ cfg.masterHostname ] ++ cfg.master.additionalSANs;
            etcClusterAdminKubeconfig = cfg.master.adminKubeconfigPath;
          };
        };

        virtualisation.containerd.settings = {
          plugins."io.containerd.cri.v1.runtime".cni.bin_dirs = [
            "/opt/cni/bin"
            "/var/lib/cni/bin"
          ];
          plugins."io.containerd.grpc.v1.cri".cni.bin_dirs = [
            "/opt/cni/bin"
            "/var/lib/cni/bin"
          ];
        };

        # Override NixOS kubernetes module's read-only Nix-store-managed /etc/cni/net.d
        # with a real writable directory so CNI plugins (e.g. cilium) can write configs there.
        environment.etc."cni/net.d" = lib.mkForce { enable = false; };

        systemd.tmpfiles.rules = [
          "d /var/lib/cni/bin 0755 root root -"
          "d /opt/cni/bin 0755 root root -"
          "d /etc/cni/net.d 0755 root root -"
        ];
      };
    };
}
