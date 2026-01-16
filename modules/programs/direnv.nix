{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.programs.direnv;
  enabledOption =
    x:
    lib.mkEnableOption x
    // {
      default = true;
      example = false;
    };
  format = pkgs.formats.toml {};
in {
  meta.maintainers = [
    lib.maintainers.mattpolzin or "mattpolzin"
  ];
  options.programs.direnv = {
    enable = lib.mkEnableOption ''
      direnv integration. Takes care of both installation and
      setting up the sourcing of the shell. Additionally enables nix-direnv
      integration.
    '';

    package = lib.mkPackageOption pkgs "direnv" {};

    finalPackage = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The wrapped direnv package.";
    };

    enableBashIntegration = enabledOption ''
      Bash integration
    '';
    enableZshIntegration = enabledOption ''
      Zsh integration
    '';
    enableFishIntegration = enabledOption ''
      Fish integration
    '';

    direnvrcExtra = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        export FOO="foo"
        echo "loaded direnv!"
      '';
      description = ''
        Extra lines to append to the sourced direnvrc
      '';
    };

    silent = lib.mkEnableOption ''
      the hiding of direnv logging
    '';

    loadInNixShell =
      (lib.mkEnableOption ''
        loading direnv in `nix-shell` `nix shell` or `nix develop`
      '')
      // {
        default = true;
      };

    nix-direnv = {
      enable =
        (lib.mkEnableOption ''
          a faster, persistent implementation of use_nix and use_flake, to replace the built-in one
        '')
        // {
          default = true;
        };

      package = lib.mkPackageOption pkgs "nix-direnv" {};
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = {};
      example = lib.literalExpression ''
        {
          global = {
            log_format = "-";
            log_filter = "^$";
          };
        }
      '';
      description = ''
        Direnv configuration. Refer to {manpage}`direnv.toml(1)`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs = {
      direnv = {
        finalPackage = pkgs.symlinkJoin {
          inherit (cfg.package) name;
          paths = [cfg.package];
          # direnv has a fish library which automatically sources direnv for some reason
          postBuild = ''
            rm -rf "$out/share/fish"
          '';
          meta.mainProgram = "direnv";
        };
        settings = lib.mkIf cfg.silent {
          global = {
            log_format = lib.mkDefault "-";
            log_filter = lib.mkDefault "^$";
          };
        };
      };
      zsh.interactiveShellInit = lib.mkIf cfg.enableZshIntegration ''
        if ${lib.boolToString cfg.loadInNixShell} || printenv PATH | grep -vqc '/nix/store'; then
         eval "$(${lib.getExe cfg.finalPackage} hook zsh)"
        fi
      '';

      #$NIX_GCROOT for "nix develop" https://github.com/NixOS/nix/blob/6db66ebfc55769edd0c6bc70fcbd76246d4d26e0/src/nix/develop.cc#L530
      #$IN_NIX_SHELL for "nix-shell"
      bash.interactiveShellInit = lib.mkIf cfg.enableBashIntegration ''
        if ${lib.boolToString cfg.loadInNixShell} || [ -z "$IN_NIX_SHELL$NIX_GCROOT$(printenv PATH | grep '/nix/store')" ] ; then
         eval "$(${lib.getExe cfg.finalPackage} hook bash)"
        fi
      '';

      fish.interactiveShellInit = lib.mkIf cfg.enableFishIntegration ''
        if ${lib.boolToString cfg.loadInNixShell};
        or printenv PATH | grep -vqc '/nix/store';
         ${lib.getExe cfg.finalPackage} hook fish | source
        end
      '';
    };

    environment = {
      systemPackages = [
        cfg.finalPackage
      ];
      variables = {
        DIRENV_CONFIG = "/etc/direnv";
      };
      etc = {
        "direnv/direnv.toml".source = lib.mkIf (cfg.settings != {}) (
          format.generate "direnv.toml" cfg.settings
        );
        "direnv/direnvrc".text = ''
          ${lib.optionalString cfg.nix-direnv.enable ''
            #Load nix-direnv
            source ${cfg.nix-direnv.package}/share/nix-direnv/direnvrc
          ''}

           #Load direnvrcExtra
           ${cfg.direnvrcExtra}

           #Load user-configuration if present (~/.direnvrc or ~/.config/direnv/direnvrc)
           direnv_config_dir_home="''${DIRENV_CONFIG_HOME:-''${XDG_CONFIG_HOME:-$HOME/.config}/direnv}"
           if [[ -f $direnv_config_dir_home/direnvrc ]]; then
             source "$direnv_config_dir_home/direnvrc" >&2
           elif [[ -f $HOME/.direnvrc ]]; then
             source "$HOME/.direnvrc" >&2
           fi

           unset direnv_config_dir_home
        '';

        "direnv/lib/zz-user.sh".text = ''
          direnv_config_dir_home="''${DIRENV_CONFIG_HOME:-''${XDG_CONFIG_HOME:-$HOME/.config}/direnv}"

          for lib in "$direnv_config_dir_home/lib/"*.sh; do
            source "$lib"
          done

          unset direnv_config_dir_home
        '';
      };
    };
  };
}
