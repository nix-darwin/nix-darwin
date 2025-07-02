{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    filterAttrs
    literalExpression
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    mkPackageOption
    recursiveUpdate
    warnIf
    types
    ;

  cfg = config.services.nebula;
  enabledNetworks = filterAttrs (n: v: v.enable) cfg.networks;

  format = pkgs.formats.yaml { };

  nameToId = netName: "nebula-${netName}";

  resolveFinalPort =
    netCfg:
    if netCfg.listen.port == null then
      if (netCfg.isLighthouse || netCfg.isRelay) then 4242 else 0
    else
      netCfg.listen.port;

in
{
  # Interface

  options.services.nebula = {
    package = mkPackageOption pkgs "nebula" { };
    networks = mkOption {
      description = "Nebula network definitions.";
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable or disable this network.";
            };

            ca = mkOption {
              type = types.path;
              description = "Path to the certificate authority certificate.";
              example = "/etc/nebula/ca.crt";
            };

            cert = mkOption {
              type = types.path;
              description = "Path to the host certificate.";
              example = "/etc/nebula/host.crt";
            };

            key = mkOption {
              type = types.oneOf [
                types.nonEmptyStr
                types.path
              ];
              description = "Path or reference to the host key.";
              example = "/etc/nebula/host.key";
            };

            staticHostMap = mkOption {
              type = types.attrsOf (types.listOf types.str);
              default = { };
              description = ''
                The static host map defines a set of hosts with fixed IP addresses on the internet (or any network).
                A host can have multiple fixed IP addresses defined here, and nebula will try each when establishing a tunnel.
              '';
              example = {
                "192.168.100.1" = [ "100.64.22.11:4242" ];
              };
            };

            isLighthouse = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this node is a lighthouse.";
            };

            isRelay = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this node is a relay.";
            };

            lighthouses = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                List of IPs of lighthouse hosts this node should report to and query from. This should be empty on lighthouse
                nodes. The IPs should be the lighthouse's Nebula IPs, not their external IPs.
              '';
              example = [ "192.168.100.1" ];
            };

            relays = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                List of IPs of relays that this node should allow traffic from.
              '';
              example = [ "192.168.100.1" ];
            };

            listen.host = mkOption {
              type = types.str;
              default = "0.0.0.0";
              description = "IP address to listen on.";
            };

            listen.port = mkOption {
              type = types.nullOr types.port;
              default = null;
              defaultText = lib.literalExpression ''
                if (config.services.nebula.networks.''${name}.isLighthouse ||
                    config.services.nebula.networks.''${name}.isRelay) then
                  4242
                else
                  0;
              '';
              description = "Port number to listen on.";
            };

            tun.disable = mkOption {
              type = types.bool;
              default = false;
              description = ''
                When tun is disabled, a lighthouse can be started without a local tun interface (and therefore without root).
              '';
            };

            tun.device = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Name of the tun device. Defaults to nebula.\${networkName}.";
            };

            firewall.outbound = mkOption {
              type = types.listOf types.attrs;
              default = [ ];
              description = "Firewall rules for outbound traffic.";
              example = [
                {
                  port = "any";
                  proto = "any";
                  host = "any";
                }
              ];
            };

            firewall.inbound = mkOption {
              type = types.listOf types.attrs;
              default = [ ];
              description = "Firewall rules for inbound traffic.";
              example = [
                {
                  port = "any";
                  proto = "any";
                  host = "any";
                }
              ];
            };

            settings = mkOption {
              inherit (format) type;
              default = { };
              description = ''
                Nebula configuration. Refer to
                <https://github.com/slackhq/nebula/blob/master/examples/config.yml>
                for details on supported values.
              '';
              example = literalExpression ''
                {
                  lighthouse.dns = {
                    host = "0.0.0.0";
                    port = 53;
                  };
                }
              '';
            };
          };
        }
      );
    };
  };

  # Implementation
  config = mkIf (enabledNetworks != { }) {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons = mkMerge (
      mapAttrsToList (
        netName: netCfg:

        let
          networkId = nameToId netName;
          settings = recursiveUpdate {
            pki = {
              inherit (netCfg) ca;
              inherit (netCfg) cert;
              inherit (netCfg) key;
            };
            static_host_map = netCfg.staticHostMap;
            lighthouse = {
              am_lighthouse = netCfg.isLighthouse;
              hosts = netCfg.lighthouses;
            };
            relay = {
              am_relay = netCfg.isRelay;
              inherit (netCfg) relays;
              use_relays = true;
            };
            listen = {
              inherit (netCfg.listen) host;
              port = resolveFinalPort netCfg;
            };
            tun = {
              disabled = netCfg.tun.disable;
              dev = if (netCfg.tun.device != null) then netCfg.tun.device else "nebula.${netName}";
            };
            firewall = {
              inherit (netCfg.firewall) inbound;
              inherit (netCfg.firewall) outbound;
            };
          } netCfg.settings;
          configFile = format.generate "nebula-config-${netName}.yml" (
            warnIf ((settings.lighthouse.am_lighthouse || settings.relay.am_relay) && settings.listen.port == 0)
              ''
                Nebula network '${netName}' is configured as a lighthouse or relay, and its port is ${builtins.toString settings.listen.port}.
                You will likely experience connectivity issues: https://nebula.defined.net/docs/config/listen/#listenport
              ''
              settings
          );
        in
        {
          "nebula-${netName}" = {
            command = "${cfg.package}/bin/nebula -config ${configFile}";
            serviceConfig = {
              KeepAlive = true;
              RunAtLoad = true;
              StandardOutPath = "/var/log/nebula-${netName}.out.log";
              StandardErrorPath = "/var/log/nebula-${netName}.err.log";
            };
          };
        }
      ) enabledNetworks
    );
  };

  meta.maintainers = with lib.maintainers; [ siriobalmelli ];
}
