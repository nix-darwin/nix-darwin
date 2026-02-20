{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.netbird;
  inherit (lib)
    attrValues
    imap0
    mapAttrs'
    mkDefault
    mkIf
    mkMerge
    mkOption
    types
    ;
  toServiceAttrs =
    fn: mapAttrs' (_: clientConfig: nameValuePair clientConfig.name (fn clientConfig)) cfg.clients;
  ifDefaults = listToAttrs (
    imap0 (idx: client: nameValuePair client.name "utun${toString (20 + idx)}") (attrValues cfg.clients)
  );
in
{
  options.services.netbird = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enables backward-compatible NetBird client service.

        This is strictly equivalent to:

        ```nix
        services.netbird.clients.default = {
          name = "netbird";
          interface = "utun100";
        };
        ```
      '';
    };
    package = mkOption {
      type = types.package;
      default = pkgs.netbird;
      defaultText = literalExpression "pkgs.netbird";
      description = "The package to use for netbird";
    };
    clients = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          let
            client = config;
          in
          {
            options = {
              name = mkOption {
                type = types.str;
                default = name;
                description = "client/network name.";
              };
              interface = mkOption {
                type = types.str;
                description = "Name of the network interface managed by this client, must be `utun[0-9]*`.";
              };

              serviceName = mkOption {
                type = types.str;
                default = if client.name != "netbird" then "netbird-${client.name}" else client.name;
                description = "Service name and directory basename.";
              };

              dir = {
                runtime = mkOption {
                  type = types.path;
                  default = "/var/run/${client.serviceName}";
                  description = "Per-service runtime files dir.";
                };
                state = mkOption {
                  type = types.path;
                  default = "/var/lib/${client.serviceName}";
                  description = "Per-service config files dir.";
                };
              };

              environment = mkOption {
                type = types.attrsOf types.str;
                description = "Environment for the netbird service, used to pass configuration options.";
              };

              wrapper = mkOption {
                type = types.package;
                internal = true;
                default =
                  let
                    makeWrapperArgs = concatLists (
                      mapAttrsToList (key: value: [
                        "--set-default"
                        key
                        value
                      ]) client.environment
                    );
                  in
                  pkgs.stdenv.mkDerivation {
                    name = "${cfg.package.name}-wrapper-${client.serviceName}";
                    meta.mainProgram = client.serviceName;
                    nativeBuildInputs = [ pkgs.makeWrapper ];
                    buildCommand = ''
                      mkdir -p "$out/bin"
                      makeWrapper ${lib.getExe cfg.package} "$out/bin/${client.serviceName}" \
                        ${escapeShellArgs makeWrapperArgs}
                    '';
                  };
              };
            };

            # default setup
            config = {
              environment = {
                NB_STATE_DIR = client.dir.state;
                NB_CONFIG = "${client.dir.state}/config.json";
                NB_DAEMON_ADDR = "unix://${client.dir.runtime}/sock";
                NB_INTERFACE_NAME = client.interface;
                NB_LOG_FILE = mkOptionDefault "console";
                NB_SERVICE = client.serviceName;
              };
              interface = mkDefault ifDefaults.${client.name};
            };
          }
        )
      );
      default = { };
      description = "Attribute set of NetBird client daemons.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.netbird.clients.default.name = mkDefault "netbird";
    })
    {
      environment.systemPackages = map (clientConfig: clientConfig.wrapper) (attrValues cfg.clients);
      launchd.daemons = mapAttrs' (
        _: client:
        nameValuePair client.serviceName {
          script = ''
            mkdir -p ${client.dir.runtime} ${client.dir.state}
            exec ${cfg.package}/bin/netbird service run
          '';
          serviceConfig = {
            EnvironmentVariables = client.environment;
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "/var/log/${client.serviceName}.out.log";
            StandardErrorPath = "/var/log/${client.serviceName}.err.log";
          };
        }
      ) cfg.clients;
    }
  ];
}
