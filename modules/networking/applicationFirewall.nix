{ config, lib, ... }:
let
  cfg = config.networking.applicationFirewall;

  socketfilterfw =
    option: value:
    lib.concatStringsSep " " [
      "/usr/libexec/ApplicationFirewall/socketfilterfw"
      "--${option}"
      (if value then "on" else "off")
    ];
in
{
  meta.maintainers = [
    (lib.maintainers.prince213 or "prince213")
    (lib.maintainers.ryanccn or "ryanccn")
  ];

  options.networking.applicationFirewall = {
    enable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = "Whether to enable application firewall.";
    };

    blockAllIncoming = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = "Whether to block all incoming connections.";
    };

    allowSigned = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = "Whether to allow built-in software to receive incoming connections.";
    };

    allowSignedApp = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = "Whether to allow downloaded signed software to receive incoming connections.";
    };

    enableStealthMode = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = "Whether to enable stealth mode.";
    };
  };

  config = {
    system.activationScripts.networking.text = ''
      echo "configuring application firewall..." >&2

      ${lib.optionalString (cfg.enable != null) (socketfilterfw "setglobalstate" cfg.enable)}
      ${lib.optionalString (cfg.blockAllIncoming != null) (
        socketfilterfw "setblockall" cfg.blockAllIncoming
      )}
      ${lib.optionalString (cfg.allowSigned != null) (socketfilterfw "setallowsigned" cfg.allowSigned)}
      ${lib.optionalString (cfg.allowSignedApp != null) (
        socketfilterfw "setallowsignedapp" cfg.allowSignedApp
      )}
      ${lib.optionalString (cfg.enableStealthMode != null) (
        socketfilterfw "setstealthmode" cfg.enableStealthMode
      )}
    '';
  };
}
