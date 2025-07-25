{
  config,
  lib,
  ...
}:

let
  cfg = config.services.timed;

  onOff = cond: if cond then "on" else "off";
in
{
  meta.maintainers = [
    (lib.maintainers.stepbrobd or "stepbrobd")
  ];

  options.services.timed = {
    enable = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = ''
        Enables the timed NTP client daemon.
      '';
    };

    servers = lib.mkOption {
      default = config.networking.timeServers;
      defaultText = lib.literalExpression "config.networking.timeServers";
      type = lib.types.listOf lib.types.str;
      description = ''
        The set of NTP servers from which to synchronise.
      '';
    };
  };

  config = {
    system.activationScripts.networking.text = ''
      echo "configuring timed..." >&2

      systemsetup -setUsingNetworkTime 'off' &> /dev/null
      systemsetup -setNetworkTimeServer ${lib.escapeShellArg (lib.concatStringsSep "\nserver " cfg.servers)} &> /dev/null
      systemsetup -setUsingNetworkTime '${onOff cfg.enable}' &> /dev/null
    '';
  };
}
