# This module manages the terminfo database
# and its integration in the system.
{
  config,
  lib,
  pkgs,
  ...
}:
{

  options = {
    environment.enableAllTerminfo = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = ''
        Whether to install all terminfo outputs
      '';
    };

    security.sudo.keepTerminfo = lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = ''
        Whether to preserve the `TERMINFO` and `TERMINFO_DIRS`
        environment variables, for `root` and the `admin` group.
      '';
    };
  };

  config = {

    # This should not contain packages that are broken or can't build, since it
    # will break this expression
    #
    # can be generated with:
    # lib.attrNames (lib.filterAttrs
    #  (_: drv: (builtins.tryEval (
    #    lib.isDerivation drv && drv ? terminfo && drv.meta.available && !drv.meta.broken && !drv.meta.unsupported)).value)
    #  pkgs)
    environment.systemPackages = lib.mkIf config.environment.enableAllTerminfo (
      map (x: x.terminfo) (
        with pkgs.pkgsBuildBuild;
        [
          alacritty
          kitty
          mtm
          rio
          rxvt-unicode-unwrapped
          rxvt-unicode-unwrapped-emoji
          st
          termite
          tmux
          wezterm
        ] ++ lib.optional (pkgs ? ghostty-bin) ghostty-bin
      )
    );

    environment.pathsToLink = [
      "/share/terminfo"
    ];

    environment.etc.terminfo = {
      source = "${config.system.path}/share/terminfo";
    };

    # TODO: use `environment.profileRelativeSessionVariables`
    environment.variables = {
      TERMINFO_DIRS = map (path: path + "/share/terminfo") config.environment.profiles ++ [ "/usr/share/terminfo" ];
    };

    environment.extraInit = ''
      # reset TERM with new TERMINFO available (if any)
      export TERM=$TERM
    '';

    security =
      let
        extraConfig = ''

          # Keep terminfo database for root and %admin.
          Defaults:root,%admin env_keep+=TERMINFO_DIRS
          Defaults:root,%admin env_keep+=TERMINFO
        '';
      in
      lib.mkIf config.security.sudo.keepTerminfo {
        sudo = { inherit extraConfig; };
      };
  };
}
