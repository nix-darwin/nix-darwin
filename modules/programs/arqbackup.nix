{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.arqbackup;
in
{
  options = {
    programs.arqbackup = {
      enable = lib.mkEnableOption "Arq backup";

      # If `arq` is not available then we set `default` to `null` to prevent
      # eval from breaking while `arq` hasn't been merged yet. Only if a user
      # enables the module will they be required to set this option.
      package = lib.mkPackageOption pkgs "arq" (lib.optionalAttrs (!pkgs ? arq) { default = null; });
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.arqagent = {
      command = "${cfg.package}/Applications/Arq.app/Contents/Resources/ArqAgent.app/Contents/MacOS/ArqAgent";
      serviceConfig.Label = "com.haystacksoftware.arqagent";
      serviceConfig.RunAtLoad = true;
      serviceConfig.KeepAlive = true;
    };

    launchd.user.agents.ArqMonitor = {
      command = "${cfg.package}/Applications/Arq.app/Contents/Resources/ArqMonitor.app/Contents/MacOS/ArqMonitor";
      serviceConfig.Label = "com.haystacksoftware.ArqMonitor";
      serviceConfig.RunAtLoad = true;
      serviceConfig.KeepAlive = true;
      managedBy = "programs.arqbackup.enable";
    };
  };
}
