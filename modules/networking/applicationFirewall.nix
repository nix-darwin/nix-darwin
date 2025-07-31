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
  ];

  options.networking.applicationFirewall = {
    enable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      example = true;
      description = "Whether to enable application firewall.";
    };
    blockAllIncoming = lib.mkEnableOption "blocking all incoming connections";
    allowSigned = lib.mkEnableOption "built-in software to receive incoming connections" // {
      default = true;
    };
    allowSignedApp =
      lib.mkEnableOption "downloaded signed software to receive incoming connections"
      // {
        default = true;
      };
    enableStealthMode = lib.mkEnableOption "stealth mode";
  };

  config = {
    system.activationScripts.networking.text = ''
      echo "configuring application firewall..." >&2

      ${lib.optionalString (cfg.enable != null) (socketfilterfw "setglobalstate" cfg.enable)}
      ${lib.optionalString (cfg.enable == true) (socketfilterfw "setblockall" cfg.blockAllIncoming)}
      ${socketfilterfw "setallowsigned" cfg.allowSigned}
      ${socketfilterfw "setallowsignedapp" cfg.allowSignedApp}
      ${socketfilterfw "setstealthmode" cfg.enableStealthMode}
    '';
  };
}
