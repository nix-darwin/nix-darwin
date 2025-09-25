{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    escapeShellArgs
    getExe
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    mkRemovedOptionModule
    types
  ;

  cfg = config.services.prometheus.exporters.node;
in {
  imports = [
    (mkRemovedOptionModule [ "services" "prometheus" "exporters" "node" "openFirewall" ] "No nix-darwin equivalent to this NixOS option.")
    (mkRemovedOptionModule [ "services" "prometheus" "exporters" "node" "firewallFilter" ] "No nix-darwin equivalent to this NixOS option.")
    (mkRemovedOptionModule [ "services" "prometheus" "exporters" "node" "firewallRules" ] "No nix-darwin equivalent to this NixOS option.")
  ];

  options = {
    services.prometheus.exporters.node = {
      enable = mkEnableOption "Prometheus Node exporter";

      package = mkPackageOption pkgs "prometheus-node-exporter" { };

      listenAddress = mkOption {
        type = types.str;
        default = "";
        example = "0.0.0.0";
        description = ''
          Address where Node exporter exposes its HTTP interface. Leave empty to bind to all addresses.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 9100;
        description = ''
          Port where the Node exporter exposes its HTTP interface.
        '';
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "--log.level=debug" ];
        description = ''
          Extra commandline options to pass to the Node exporter executable.
        '';
      };

      enabledCollectors = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = ''
          Collectors to enable in addition to the ones that are [enabled by default](https://github.com/prometheus/node_exporter#enabled-by-default).
        '';
      };

      disabledCollectors = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "boottime" ];
        description = ''
          Collectors to disable from the list of collectors that are [enabled by default](https://github.com/prometheus/node_exporter#enabled-by-default).
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    users.users._prometheus-node-exporter = {
      uid = config.ids.uids._prometheus-node-exporter;
      gid = config.ids.gids._prometheus-node-exporter;
      home = "/private/var/lib/prometheus-node-exporter";
      createHome = true;
      shell = "/usr/bin/false";
      description = "System user for the Prometheus Node exporter";
    };

    users.groups._prometheus-node-exporter = {
      gid = config.ids.gids._prometheus-node-exporter;
      description = "System group for the Prometheus Node exporter";
    };

    users.knownGroups = [ "_prometheus-node-exporter" ];
    users.knownUsers = [ "_prometheus-node-exporter" ];

    launchd.daemons.prometheus-node-exporter = {
      script = concatStringsSep " "
        ([
          (getExe cfg.package)
          "--web.listen-address"
          "${cfg.listenAddress}:${toString cfg.port}"
        ]
        ++ (map (collector: "--collector.${collector}") cfg.enabledCollectors)
        ++ (map (collector: "--no-collector.${collector}") cfg.disabledCollectors)
      ) + escapeShellArgs cfg.extraFlags;
      serviceConfig = let
        logPath = config.users.users._prometheus-node-exporter.home
          + "/prometheus-node-exporter.log";
      in {
        KeepAlive = true;
        RunAtLoad = true;
        StandardErrorPath = logPath;
        StandardOutPath = logPath;
        GroupName = "_prometheus-node-exporter";
        UserName = "_prometheus-node-exporter";
      };
    };
  };
}
