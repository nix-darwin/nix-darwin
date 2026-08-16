{
  options,
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.environment;

  exportVariables = mapAttrsToList (n: v: ''export ${n}="${v}"'') cfg.variables;

  aliasCommands = mapAttrsToList (n: v: ''alias ${n}=${escapeShellArg v}'') (
    filterAttrs (k: v: v != null) cfg.shellAliases
  );
in

{
  imports = [
    (mkRemovedOptionModule [ "environment" "loginShell" ] ''
      This option was only used to change the default command in tmux.

      This has been removed in favour of changing the default command or default shell in tmux directly.
    '')
  ];

  options = {
    environment.profiles = mkOption {
      type = types.listOf types.str;
      description = "A list of profiles used to setup the global environment.";
    };

    environment.darwinConfig = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default =
        if config.nixpkgs.flake.setNixPath then
          # Don’t set this for flake‐based systems.
          null
        else if config.system.stateVersion >= 6 then
          "/etc/nix-darwin/configuration.nix"
        else
          "${config.system.primaryUserHome}/.nixpkgs/darwin-configuration.nix";
      defaultText = literalExpression ''
        if config.nixpkgs.flake.setNixPath then
          # Don’t set this for flake‐based systems.
          null
        else if config.system.stateVersion >= 6 then
          "/etc/nix-darwin/configuration.nix"
        else
          "''${config.system.primaryUserHome}/.nixpkgs/darwin-configuration.nix"
      '';
      description = ''
        The path of the darwin configuration.nix used to configure the system,
        this updates the default darwin-config entry in NIX_PATH. Since this
        changes an environment variable it will only apply to new shells.

        NOTE: Changing this requires running {command}`darwin-rebuild switch -I darwin-config=/path/to/configuration.nix`
        the first time to make darwin-rebuild aware of the custom location.
      '';
    };

    environment.variables = mkOption {
      type = types.attrsOf (types.either types.str (types.listOf types.str));
      default = { };
      example = {
        EDITOR = "vim";
        LANG = "nl_NL.UTF-8";
      };
      description = ''
        A set of environment variables used in the global environment.
        These variables will be set on shell initialisation.
        The value of each variable can be either a string or a list of
        strings.  The latter is concatenated, interspersed with colon
        characters.
      '';
      apply = mapAttrs (n: v: if isList v then concatStringsSep ":" v else v);
    };

    environment.shellAliases = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        ll = "ls -l";
      };
      description = ''
        An attribute set that maps aliases (the top level attribute names in
        this option) to command strings or directly to build outputs. The
        alises are added to all users' shells.
      '';
    };

    environment.extraInit = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Shell script code called during global environment initialisation
        after all variables and profileVariables have been set.
        This code is assumed to be shell-independent, which means you should
        stick to pure sh without sh word split.
      '';
    };

    environment.shellInit = mkOption {
      default = "";
      description = ''
        Shell script code called during shell initialisation.
        This code is asumed to be shell-independent, which means you should
        stick to pure sh without sh word split.
      '';
      type = types.lines;
    };

    environment.loginShellInit = mkOption {
      default = "";
      description = ''
        Shell script code called during login shell initialisation.
        This code is asumed to be shell-independent, which means you should
        stick to pure sh without sh word split.
      '';
      type = types.lines;
    };

    environment.interactiveShellInit = mkOption {
      default = "";
      description = ''
        Shell script code called during interactive shell initialisation.
        This code is asumed to be shell-independent, which means you should
        stick to pure sh without sh word split.
      '';
      type = types.lines;
    };
    environment.extraAppPaths = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        		A list of extra paths to link
        	  '';
    };
  };

  config = {

    # This is horrible, sorry.
    system.requiresPrimaryUser =
      mkIf
        (
          config.nix.enable
          && !config.nixpkgs.flake.setNixPath
          && config.system.stateVersion < 6
          && options.environment.darwinConfig.highestPrio == (mkOptionDefault { }).priority
        )
        [
          "environment.darwinConfig"
        ];

    environment.systemPath = mkMerge [
      [ (makeBinPath cfg.profiles) ]
      (mkOrder 1200 [ "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" ])
    ];

    # Use user, default and system profiles.
    environment.profiles = mkMerge [
      (mkOrder 800 [ "$HOME/.nix-profile" ])
      [
        "/run/current-system/sw"
        "/nix/var/nix/profiles/default"
      ]
    ];

    environment.extraInit = ''
      export NIX_USER_PROFILE_DIR="/nix/var/nix/profiles/per-user/$USER"
      export NIX_PROFILES="${concatStringsSep " " (reverseList cfg.profiles)}"
    '';

    environment.variables = {
      XDG_CONFIG_DIRS = map (path: path + "/etc/xdg") cfg.profiles;
      XDG_DATA_DIRS = map (path: path + "/share") cfg.profiles;
      EDITOR = mkDefault "nano";
      PAGER = mkDefault "less -R";
    };

    system.build.setEnvironment = pkgs.writeText "set-environment" ''
      # Prevent this file from being sourced by child shells.
      export __NIX_DARWIN_SET_ENVIRONMENT_DONE=1

      export PATH=${config.environment.systemPath}
      ${concatStringsSep "\n" exportVariables}

      # Extra initialisation
      ${cfg.extraInit}
    '';

    system.build.setAliases = pkgs.writeText "set-aliases" ''
      ${concatStringsSep "\n" aliasCommands}
    '';
  };
}
