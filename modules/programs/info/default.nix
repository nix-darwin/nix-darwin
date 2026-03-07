{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.programs.info;
in

{
  options = {
    programs.info.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable info pages and the {command}`info` command.";
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.texinfoInteractive ];

    environment.pathsToLink = [
      "/info"
      "/share/info"
    ];
    environment.extraOutputsToInstall = [ "info" ];

    environment.extraSetup = ''
      if test -w $out/share/info; then
        shopt -s nullglob
        for i in $out/share/info/*.info $out/share/info/*.info.gz; do
          ${pkgs.texinfoInteractive}/bin/install-info $i $out/share/info/dir
        done
      fi
    '';

  };
}
