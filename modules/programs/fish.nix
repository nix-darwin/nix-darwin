{ config, lib, pkgs, ... }:

with lib;

let

  cfge = config.environment;

  cfg = config.programs.fish;

  fishAliases = concatStringsSep "\n" (
    mapAttrsToList (k: v: "alias ${k} ${escapeShellArg v}")
      (filterAttrs (k: v: v != null) cfg.shellAliases)
  );

  envShellInit = pkgs.writeText "shellInit" cfge.shellInit;

  envLoginShellInit = pkgs.writeText "loginShellInit" cfge.loginShellInit;

  envInteractiveShellInit = pkgs.writeText "interactiveShellInit" cfge.interactiveShellInit;

  fenv = pkgs.fishPlugins.foreign-env or pkgs.fish-foreign-env;

  # fishPlugins.foreign-env and fish-foreign-env have different function paths
  fenvFunctionsDir = if (pkgs ? fishPlugins.foreign-env)
    then "${fenv}/share/fish/vendor_functions.d"
    else "${fenv}/share/fish-foreign-env/functions";

  sourceEnv = file:
  if cfg.useBabelfish then
    "source /etc/fish/${file}.fish"
  else
    ''
      set fish_function_path ${fenvFunctionsDir} $fish_function_path
      fenv source /etc/fish/foreign-env/${file} > /dev/null
      set -e fish_function_path[1]
    '';

  babelfishTranslate = path: name:
    pkgs.runCommand "${name}.fish" {} ''
      ${cfg.babelfishPackage}/bin/babelfish < ${path} > $out
    '';

in

{

  options = {

    programs.fish = {

      enable = mkOption {
        default = false;
        description = ''
          Whether to configure fish as an interactive shell.
        '';
        type = types.bool;
      };

      package = lib.mkPackageOption pkgs "fish" { };

      useBabelfish = mkOption {
        type = types.bool;
        default = false;
        description = ''
          If enabled, the configured environment will be translated to native fish using [babelfish](https://github.com/bouk/babelfish).
          Otherwise, [foreign-env](https://github.com/oh-my-fish/plugin-foreign-env) will be used.
        '';
      };

      babelfishPackage = mkOption {
        type = types.package;
        default = pkgs.babelfish;
        description = ''
          The babelfish package to use when useBabelfish is
          set to true.
        '';
      };

      vendor.config.enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether fish should source configuration snippets provided by other packages.
        '';
      };

      vendor.completions.enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether fish should use completion files provided by other packages.
        '';
      };

      vendor.functions.enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether fish should autoload fish functions provided by other packages.
        '';
      };

      shellAliases = mkOption {
        default = config.environment.shellAliases;
        description = ''
          Set of aliases for fish shell. See {option}`environment.shellAliases`
          for an option format description.
        '';
        type = types.attrs;
      };

      shellInit = mkOption {
        default = "";
        description = ''
          Shell script code called during fish shell initialisation.
        '';
        type = types.lines;
      };

      loginShellInit = mkOption {
        default = "";
        description = ''
          Shell script code called during fish login shell initialisation.
        '';
        type = types.lines;
      };

      interactiveShellInit = mkOption {
        default = "";
        description = ''
          Shell script code called during interactive fish shell initialisation.
        '';
        type = types.lines;
      };

      promptInit = mkOption {
        default = "";
        description = ''
          Shell script code used to initialise fish prompt.
        '';
        type = types.lines;
      };

    };

  };

  config = mkIf cfg.enable {

    environment = mkMerge [
      (mkIf cfg.useBabelfish
      {
        etc."fish/setEnvironment.fish".source = babelfishTranslate config.system.build.setEnvironment "setEnvironment";
        etc."fish/shellInit.fish".source = babelfishTranslate envShellInit "shellInit";
        etc."fish/loginShellInit.fish".source = babelfishTranslate envLoginShellInit "loginShellInit";
        etc."fish/interactiveShellInit.fish".source = babelfishTranslate envInteractiveShellInit "interactiveShellInit";
     })

      (mkIf (!cfg.useBabelfish)
      {
        etc."fish/foreign-env/shellInit".source = envShellInit;
        etc."fish/foreign-env/loginShellInit".source = envLoginShellInit;
        etc."fish/foreign-env/interactiveShellInit".source = envInteractiveShellInit;
      })

      {
        etc."fish/nixos-env-preinit.fish".text =
        if cfg.useBabelfish
        then ''
          # source the NixOS environment config
          if [ -z "$__NIX_DARWIN_SET_ENVIRONMENT_DONE" ]
            source /etc/fish/setEnvironment.fish
          end
        ''
        else ''
          # This happens before $__fish_datadir/config.fish sets fish_function_path, so it is currently
          # unset. We set it and then completely erase it, leaving its configuration to $__fish_datadir/config.fish
          set fish_function_path ${fenvFunctionsDir} $__fish_datadir/functions

          # source the NixOS environment config
          if [ -z "$__NIX_DARWIN_SET_ENVIRONMENT_DONE" ]
            fenv source ${config.system.build.setEnvironment}
          end

          # clear fish_function_path so that it will be correctly set when we return to $__fish_datadir/config.fish
          set -e fish_function_path
        '';
      }
      {
        etc."fish/config.fish".text = ''
        # /etc/fish/config.fish: DO NOT EDIT -- this file has been generated automatically.

        # Only execute this file once per shell.
        set -q __fish_nix_darwin_config_sourced; and exit
        set -g __fish_nix_darwin_config_sourced 1

        ${sourceEnv "shellInit"}

        ${cfg.shellInit}

        status --is-login; and begin
          ${sourceEnv "loginShellInit"}

          ${cfg.loginShellInit}
        end

        status --is-interactive; and begin
          ${fishAliases}

          ${sourceEnv "interactiveShellInit"}

          ${cfg.promptInit}
          ${cfg.interactiveShellInit}
        end
      '';
      }

      # include programs that bring their own completions
      {
        pathsToLink = []
          ++ optional cfg.vendor.config.enable "/share/fish/vendor_conf.d"
          ++ optional cfg.vendor.completions.enable "/share/fish/vendor_completions.d"
          ++ optional cfg.vendor.functions.enable "/share/fish/vendor_functions.d";
      }

      { systemPackages = [ cfg.package ]; }
    ];
  };

}
