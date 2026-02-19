{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.cloudflare-warp;
in
{
  options = {
    programs.cloudflare-warp = {
      enable = lib.mkEnableOption "the Cloudflare WARP application";
      package = lib.mkPackageOption pkgs "Cloudflare WARP" {
        default = [ "cloudflare-warp" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.cloudflare-warp = {
      serviceConfig = {
        Label = "com.cloudflare.1dot1dot1dot1.macos.warp.daemon";
        ProgramArguments = [
          "${cfg.package}/Applications/Cloudflare WARP.app/Contents/Resources/CloudflareWARP"
        ];
        UserName = "root";
        RunAtLoad = true;
        KeepAlive = true;
        SoftResourceLimits = {
          NumberOfFiles = 32768;
        };
      };
    };
  };

  meta.maintainers = [
    lib.maintainers.anish
  ];
}
