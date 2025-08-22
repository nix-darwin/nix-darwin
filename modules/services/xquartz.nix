{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.services.xquartz;
  xauth = pkgs.xorg.xauth;
in {
  options.services.xquartz = {
    enable = mkEnableOption "XQuartz";
    package = mkOption {
      type = types.package;
      default = pkgs.xquartz;
      description = "The XQuartz package to use.";
    };
  };

  config = mkIf cfg.enable {
    environment = let
      daemon = "org.nixos.xquartz.privileged_startx.plist";
      agent = "org.nixos.xquartz.startx.plist";
    in {
      systemPackages = [ cfg.package ];

      launchDaemons.${daemon}.source =
        (pkgs.substitute {
          src = "${builtins.dirOf (builtins.unsafeGetAttrPos "pname" cfg.package).file}/${daemon}";
          substitutions = [
            "--replace-fail"
            "@PRIVILEGED_STARTX@"
            "${cfg.package}/libexec/privileged_startx"

            "--replace-fail"
            "@PRIVILEGED_STARTX_D@"
            "${cfg.package}/etc/X11/xinit/privileged_startx.d"
          ];
        }).outPath;

      launchAgents.${agent}.source =
        (pkgs.substitute {
          src = "${builtins.dirOf (builtins.unsafeGetAttrPos "pname" cfg.package).file}/${agent}";
          substitutions = [
            "--replace-fail"
            "@LAUNCHD_STARTX@"
            "${cfg.package}/libexec/launchd_startx"

            "--replace-fail"
            "@STARTX@"
            "${cfg.package}/bin/startx"

            "--replace-fail"
            "@XQUARTZ@"
            "${cfg.package}/bin/Xquartz"
          ];
        }).outPath;
        etc."ssh/ssh_config.d/70-xquartz.conf".text = ''
          XAuthLocation ${xauth}/bin/xauth
        '';
    };
  };
}
