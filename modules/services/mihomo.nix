{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.mihomo;
  dataDir = "/var/db/mihomo";

  command =
    lib.concatStringsSep " " (
      map lib.escapeShellArg [
        (lib.getExe cfg.package)
        "-d"
        dataDir
        "-f"
        (toString cfg.configFile)
      ]
      ++ lib.optionals (cfg.webui != null) [
        "-ext-ui"
        (toString cfg.webui)
      ]
    )
    + lib.optionalString (cfg.extraOpts != null) " ${cfg.extraOpts}";
in
{
  options.services.mihomo = {
    enable = lib.mkEnableOption "Mihomo, a rule-based proxy in Go";

    package = lib.mkPackageOption pkgs "mihomo" { };

    configFile = lib.mkOption {
      type = lib.types.externalPath;
      description = "Configuration file to use.";
    };

    webui = lib.mkOption {
      default = null;
      type = lib.types.nullOr lib.types.path;
      example = lib.literalExpression "pkgs.metacubexd";
      description = ''
        Local web interface to use.

        You can also use the following website:
        - metacubexd:
          - <https://d.metacubex.one>
          - <https://metacubex.github.io/metacubexd>
          - <https://metacubexd.pages.dev>
        - yacd:
          - <https://yacd.haishan.me>
        - clash-dashboard:
          - <https://clash.razord.top>
      '';
    };

    extraOpts = lib.mkOption {
      default = null;
      type = lib.types.nullOr lib.types.str;
      description = "Extra command line options to use.";
    };

  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.mihomo = {
      inherit command;
      serviceConfig = {
        Label = "org.nixos.mihomo";
        UserName = "root";
        KeepAlive = true;
        RunAtLoad = true;
        ProcessType = "Background";
        StandardOutPath = "/var/log/mihomo.log";
        StandardErrorPath = "/var/log/mihomo.log";
      };
    };

    system.activationScripts.preActivation.text = ''
      mkdir -p ${lib.escapeShellArg dataDir}
      chmod 700 ${lib.escapeShellArg dataDir}
    '';
  };
}
