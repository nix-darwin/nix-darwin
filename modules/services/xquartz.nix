{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.xquartz;
in
{
  options.services.xquartz = {
    enable = lib.mkEnableOption "XQuartz";

    package = lib.mkPackageOption pkgs "xquartz" { };

    configureSsh = lib.mkEnableOption "OpenSSH client integration for X11 forwarding";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = [ cfg.package ];

        launchd.agents.xquartz-startx = {
          command = lib.escapeShellArgs [
            "${cfg.package}/libexec/launchd_startx"
            "${cfg.package}/bin/startx"
            "--"
            "${cfg.package}/bin/Xquartz"
          ];
          serviceConfig = {
            Label = "org.nixos.xquartz.startx";
            Sockets."org.nixos.xquartz:0".SecureSocketWithKey = "DISPLAY";
            # xinit uses vproc_transaction_begin while the X11 session runs.
            EnableTransactions = true;
          };
        };

        launchd.daemons.xquartz-privileged-startx = {
          command = lib.escapeShellArgs [
            "${cfg.package}/libexec/privileged_startx"
            "-d"
            "${cfg.package}/etc/X11/xinit/privileged_startx.d"
          ];
          serviceConfig = {
            Label = "org.nixos.xquartz.privileged_startx";
            MachServices."org.nixos.xquartz.privileged_startx" = true;
          };
        };
      }

      (lib.mkIf cfg.configureSsh {
        programs.ssh.extraConfig = lib.mkAfter ''
          XAuthLocation ${lib.getExe pkgs.xauth}
        '';
      })
    ]
  );
}
