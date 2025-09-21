{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.karabiner-dk;

  parentAppDir = "/Applications/Nix Apps";
in
{
  meta.maintainers = [ lib.maintainers.auscyber or "auscyber" ];
  options.services.karabiner-dk = {
    enable = mkEnableOption "Karabiner-DK";
    package = mkPackageOption pkgs "karabiner-dk" { };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
    launchd.daemons.Karabiner-DriverKit-VirtualHIDDevice-Daemon = {
      serviceConfig.ProgramArguments = [
        "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon"
      ];
      serviceConfig.ProcessType = "Interactive";
      serviceConfig.Label = "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice-Daemon";
      serviceConfig.RunAtLoad = true;
      serviceConfig.KeepAlive = true;
    };
    launchd.daemons.start-karabiner-dk = {
      script = ''
        		spctl -a -vvv -t install "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
                "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager" activate
      '';
      serviceConfig.Label = "org.nixos.start-karabiner-dk";
      serviceConfig.RunAtLoad = true;
    };
    launchd.user.agents.activate_karabiner_system_ext = {
      serviceConfig.ProgramArguments = [
        "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager"
        "activate"
      ];
      serviceConfig.RunAtLoad = true;
      managedBy = "services.karabiner-dk.enable";
    };
    system.activationScripts.postActivation.text = ''
      		launchctl kickstart -k system/org.pqrs.Karabiner-DriverKit-VirtualHIDDevice-Daemon
      	'';
  };
}
