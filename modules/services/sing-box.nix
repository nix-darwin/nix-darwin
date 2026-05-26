{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sing-box;
in
{
  meta.maintainers = [ lib.maintainers.proteus or "Proteus Qian" ];
  options.services.sing-box = {
    enable = lib.mkEnableOption "sing-box universal proxy platform";
    package = lib.mkPackageOption pkgs "sing-box" { };
    configFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the sing-box config file";
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    system.activationScripts.postActivation.text = ''
      # Ensure the sing-box state directory is initialized
      if [ ! -d ${lib.escapeShellArg config.launchd.daemons.sing-box.serviceConfig.WorkingDirectory} ]; then
        echo "Setting up Sing-box directory..."
        install -dm700 ${lib.escapeShellArg config.launchd.daemons.sing-box.serviceConfig.WorkingDirectory}
      fi
    '';
    launchd.daemons.sing-box.serviceConfig = {
      Label = "io.nekohasekai.sing-box";
      RunAtLoad = true;
      KeepAlive = {
        Crashed = true;
        SuccessfulExit = false;
      };
      WorkingDirectory = "/Library/Application Support/sing-box";
      StandardErrorPath = "/Library/Logs/io.nekohasekai.sing-box.stderr.log";
      StandardOutPath = "/Library/Logs/io.nekohasekai.sing-box.stdout.log";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        ("/bin/wait4path /nix/store" + " && exec ${lib.getExe cfg.package} -c ${cfg.configFile} run")
      ];
    };
  };
}
