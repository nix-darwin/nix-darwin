{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sing-box;
  sing-box_dir = "/Library/Application Support/sing-box";
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
      echo "Setting up Sing-box directory..."
      if [ ! -d "${sing-box_dir}" ]; then install -dm700 ${lib.escapeShellArg sing-box_dir}; fi
    '';
    launchd.daemons.sing-box.serviceConfig = {
      Label = "io.nekohasekai.sing-box";
      RunAtLoad = true;
      KeepAlive = {
        Crashed = true;
        SuccessfulExit = false;
      };
      WorkingDirectory = sing-box_dir;
      StandardErrorPath = "/Library/Logs/io.nekohasekai.sing-box.stderr.log";
      StandardOutPath = "/Library/Logs/io.nekohasekai.sing-box.stdout.log";
      ProgramArguments = [
        "/bin/sh"
        "-c"
        (
          "/bin/wait4path /nix/store"
          + " && exec ${lib.getExe cfg.package} -c ${cfg.configFile} -D ${lib.escapeShellArg sing-box_dir} run"
        )
      ];
    };
  };
}
