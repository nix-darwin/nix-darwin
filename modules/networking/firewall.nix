{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.networking.firewall;

  onOff = cond: if cond then "on" else "off";

  anchor = pkgs.writeText "nix" (
    ''
      #
      # pf rules managed by nix-darwin
      #

    ''
    + cfg.pf.rules
  );
in
{
  options = {
    networking.firewall = {
      enable = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to enable Apple's built-in application firewall.

          The default is null which lets macOS manage the firewall.
        '';
      };

      stealthmode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable stealth mode.
        '';
      };

      pf = {
        enable = lib.mkEnableOption "packet filtering with pf";
        rules = lib.mkOption {
          default = "";
          type = lib.types.lines;
          description = ''
            Packet filtering rules for {manpage}`pf(4)`.
            See {manpage}`pf.conf(5)` for documentation.
          '';
        };
      };
    };
  };

  config = {
    system.activationScripts.networking.text = lib.mkMerge [
      (lib.mkIf (cfg.enable != null) ''
        /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate ${onOff cfg.enable}
        /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode ${onOff cfg.stealthmode}
      '')

      (lib.mkIf (!cfg.pf.enable) ''
        pfctl -a com.apple/nix -F all &> /dev/null

        # Disable pf unless stealth mode is enabled (this is the default behavior in macOS).
        if [ "$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode)" == "Firewall stealth mode is off" ]; then
          pfctl -d &> /dev/null
        fi
      '')
    ];

    launchd.daemons.pf = lib.mkIf cfg.pf.enable {
      serviceConfig = {
        ProgramArguments = [
          "/bin/sh"
          "-c"
          "/bin/wait4path /nix/store &amp;&amp; exec /sbin/pfctl -e -a com.apple/nix -f ${anchor}"
        ];

        RunAtLoad = true;
      };
    };
  };
}
