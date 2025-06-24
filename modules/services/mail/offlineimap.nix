{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.offlineimap;
in {

  options.services.offlineimap = {
    enable = mkEnableOption "Offlineimap, a software to dispose your mailbox(es) as a local Maildir(s)";

    package = mkOption {
      type = types.package;
      default = pkgs.offlineimap;
      defaultText = "pkgs.offlineimap";
      description = "Offlineimap derivation to use.";
    };

    path = mkOption {
      type = types.listOf types.path;
      default = [];
      example = literalExpression "[ pkgs.pass pkgs.bash pkgs.notmuch ]";
      description = "List of derivations to put in Offlineimap's path.";
    };

    startInterval = mkOption {
      type = types.nullOr types.int;
      default = 300;
      description = "Optional key to start offlineimap services each N seconds";
    };

    runQuick = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Run only quick synchronizations.
        Ignore any flag updates on IMAP servers. If a flag on the remote IMAP changes, and we have the message locally, it will be left untouched in a quick run.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional text to be appended to {file}`offlineimaprc`.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc."offlineimaprc".text = cfg.extraConfig;
    launchd.user.agents.offlineimap = {
      path                            = [ cfg.package ];
      command                         = "${cfg.package}/bin/offlineimap -c /etc/offlineimaprc" + optionalString (cfg.runQuick) " -q";
      serviceConfig.KeepAlive         = false;
      serviceConfig.RunAtLoad         = true;
      serviceConfig.StartInterval     = cfg.startInterval;
      serviceConfig.StandardErrorPath = "/var/log/offlineimap.log";
      serviceConfig.StandardOutPath   = "/var/log/offlineimap.log";
      managedBy = "services.offlineimap.enable";
    };
  };
}
