{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

{
  options = {

    programs.man.enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable manual pages and the {command}`man` command.
        This also includes "man" outputs of all `systemPackages`.
      '';
    };

  };

  config = mkIf config.programs.man.enable {

    environment.pathsToLink = [ "/share/man" ];

    environment.extraOutputsToInstall = [ "man" ];

  };
}
