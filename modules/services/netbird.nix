{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrValues
    concatLists
    escapeShellArgs
    getExe
    literalExpression
    maintainers
    mapAttrs'
    mapAttrsToList
    mkDefault
    mkIf
    mkMerge
    mkOption
    mkOptionDefault
    mkPackageOption
    nameValuePair
    types
    unique
    ;

  cfg = config.services.netbird;
  clientList = attrValues cfg.clients;
  serviceNames = map (c: c.serviceName) clientList;
in
{
  meta.maintainers = [ maintainers.siriobalmelli ];

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

    package = mkPackageOption pkgs "netbird" { };

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
                description = "Client/network name.";
              };

              interface = mkOption {
                type = types.strMatching "utun[0-9]+";
                description = "Network interface managed by this client (must match `utun[0-9]+`).";
              };

              serviceName = mkOption {
                type = types.str;
                default = if client.name != "netbird" then "netbird-${client.name}" else client.name;
                description = "Launchd service name and directory basename.";
              };

              dir = {
                runtime = mkOption {
                  type = types.path;
                  default = "/var/run/${client.serviceName}";
                  description = "Per-client runtime directory.";
                };
                state = mkOption {
                  type = types.path;
                  default = "/var/lib/${client.serviceName}";
                  description = "Per-client state/config directory.";
                };
              };

              environment = mkOption {
                type = types.attrsOf types.str;
                default = { };
                description = "Environment variables for the netbird daemon.";
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
                      makeWrapper ${getExe cfg.package} "$out/bin/${client.serviceName}" \
                        ${escapeShellArgs makeWrapperArgs}
                    '';
                  };
              };
            };

            config.environment = {
              NB_STATE_DIR = client.dir.state;
              NB_CONFIG = "${client.dir.state}/config.json";
              NB_DAEMON_ADDR = "unix://${client.dir.runtime}/sock";
              NB_INTERFACE_NAME = client.interface;
              NB_LOG_FILE = mkOptionDefault "console";
              NB_SERVICE = client.serviceName;
            };
          }
        )
      );
      default = { };
      description = "Attribute set of NetBird client daemons.";
      example = literalExpression ''
        {
          work = { interface = "utun100"; };
          home = { interface = "utun101"; };
        }
      '';
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.netbird.clients.default = {
        name = mkDefault "netbird";
        interface = mkDefault "utun100";
      };
    })
    {
      assertions = [
        {
          assertion = serviceNames == unique serviceNames;
          message = "services.netbird: all clients must have unique serviceName values.";
        }
      ];

      environment.systemPackages = map (c: c.wrapper) clientList;

      launchd.daemons = mapAttrs' (
        _: client:
        nameValuePair client.serviceName {
          script = ''
            install -d -m 0755 ${client.dir.runtime}
            install -d -m 0700 ${client.dir.state}
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
