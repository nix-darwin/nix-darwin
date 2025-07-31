{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.privoxy;
in
{
  options = {
    services.privoxy.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the privoxy proxy service.";
    };

    services.privoxy.listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1:8118";
      description = "The address and TCP port on which privoxy will listen.";
    };

    services.privoxy.package = mkOption {
      type = types.package;
      default = pkgs.privoxy;
      example = literalExpression "pkgs.privoxy";
      description = "This option specifies the privoxy package to use.";
    };

    services.privoxy.config = mkOption {
      type = types.lines;
      default = "";
      example = "forward / upstream.proxy:8080";
      description = "Config to use for privoxy";
    };

    services.privoxy.templdir = mkOption {
      type = types.path;
      default = "${pkgs.privoxy}/etc/templates";
      defaultText = "\${pkgs.privoxy}/etc/templates";
      description = "Directory for privoxy template files.";
    };

    services.privoxy.confdir = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Directory for privoxy files such as .action and .filter.";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."privoxy-config".text = ''
      ${optionalString (cfg.confdir != null) "confdir ${cfg.confdir}"}
      templdir ${cfg.templdir}
      listen-address ${cfg.listenAddress}
      ${cfg.config}
    '';

    launchd.user.agents.privoxy = {
      path = [ config.environment.systemPath ];
      command = ''
      ${cfg.package}/bin/privoxy /etc/privoxy-config
      '';
      serviceConfig.KeepAlive = true;
      managedBy = "services.privoxy.enable";
    };
  };
}
