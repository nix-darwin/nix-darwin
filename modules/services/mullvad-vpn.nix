{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.mullvad-vpn;
in
{
  options.services.mullvad-vpn = {
    enable = mkEnableOption "Mullvad VPN daemon";
    package = mkPackageOption pkgs "mullvad" {
      example = "pkgs.mullvad-vpn";
      extraDescription = ''
        `pkgs.mullvad` only provides the CLI tool, `pkgs.mullvad-vpn` provides both the CLI and the GUI.
      '';
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    launchd.daemons.mullvad-vpn = {
      # derived from
      # https://github.com/mullvad/mullvadvpn-app/blob/main/dist-assets/pkg-scripts/postinstall#L42
      command = "${lib.getExe' cfg.package "mullvad-daemon"} -vv";
      serviceConfig = {
        Label = "net.mullvad.daemon";
        RunAtLoad = true;
        KeepAlive = true;
        SoftResourceLimits.NumberOfFiles = 1024;
        StandardErrorPath = /var/log/mullvad-vpn/stderr.log;
      };
    };
  };
}
