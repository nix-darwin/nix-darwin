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
      enable = lib.mkEnableOption "the Cloudflare WARP application" // {
        description = ''
          Whether to enable the Cloudflare WARP application and its daemon.

          ::: {.note}

          Uninstall any copy from Cloudflare's installer first, with
          `sudo "/Applications/Cloudflare WARP.app/Contents/Resources/uninstall.sh"`.
          If `warp-cli registration new` then fails with "Failed to save to disk",
          remove the stale keychain entry and restart the daemon:

          ```
          sudo security delete-generic-password -s "WARP" /Library/Keychains/System.keychain
          sudo launchctl kickstart -k system/com.cloudflare.1dot1dot1dot1.macos.warp.daemon
          ```

          :::
        '';
      };
      package = lib.mkPackageOption pkgs "Cloudflare WARP" {
        default = [ "cloudflare-warp" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.cloudflare-warp = {
      command = lib.escapeShellArg "${cfg.package}/Applications/Cloudflare WARP.app/Contents/Resources/CloudflareWARP";
      serviceConfig = {
        Label = "com.cloudflare.1dot1dot1dot1.macos.warp.daemon";
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
    lib.maintainers.anish or "anish"
  ];
}
