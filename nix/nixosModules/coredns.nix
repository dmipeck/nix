{ inputs, ... }:

{
  flake.nixosModules.coredns =
    { pkgs, ... }:
    {
      services.coredns = {
        enable = true;
        config = ''
          . {
            hosts {
              10.5.5.8 loadbalancer loadbalancer.build13.internal
              10.5.5.2 sgh612xnml sgh612xnml.build13.internal
              10.5.5.3 sgh545vc63 sgh545vc63.build13.internal
              10.5.5.4 sgh612xnmk sgh612xnmk.build13.internal
              10.5.5.4 api.kube.build13.com
              fallthrough
            }

            forward . 8.8.8.8 8.8.4.4 {
              max_concurrent 1000
            }

            cache 30
            errors
            log
          }
        '';
      };

      networking.firewall.allowedUDPPorts = [ 53 ];
      networking.firewall.allowedTCPPorts = [ 53 ];
    };
}
