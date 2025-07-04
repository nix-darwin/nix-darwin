{ name, lib, ... }:

{
  options =
    let
      inherit (lib) literalExpression mkOption types;
    in
    {
      name = mkOption {
        type = types.nonEmptyStr;
        default = name;
        description = ''
          The name of the user account. If undefined, the name of the
          attribute set will be used.
        '';
      };

      description = mkOption {
        type = types.nullOr types.nonEmptyStr;
        default = null;
        example = "Alice Q. User";
        description = ''
          A short description of the user account, typically the
          user's full name.

          This defaults to `null` which means, on creation, `sysadminctl`
          will pick the description which is usually always {option}`name`.

          Using an empty name is not supported and breaks macOS like
          making the user not appear in Directory Utility.
        '';
      };

      uid = mkOption {
        type = types.int;
        description = "The user's UID.";
      };

      gid = mkOption {
        type = types.int;
        default = 20;
        description = "The user's primary group.";
      };

      isHidden = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to make the user account hidden.";
      };

      # extraGroups = mkOption {
      #   type = types.listOf types.str;
      #   default = [];
      #   description = "The user's auxiliary groups.";
      # };

      home = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          The user's home directory. This defaults to `null`.

          When this is set to `null`, if the user has not been created yet,
          they will be created with the home directory `/var/empty` to match
          the old default.
        '';
      };

      createHome = mkOption {
        type = types.bool;
        default = false;
        description = "Create the home directory when creating the user.";
      };

      shell = mkOption {
        type = types.nullOr (types.either types.shellPackage types.path);
        default = null;
        example = literalExpression "pkgs.bashInteractive";
        description = ''
          The user's shell. This defaults to `null`.

          When this is set to `null`, if the user has not been created yet,
          they will be created with the shell `/usr/bin/false` to prevent
          interactive login. If the user already exists, the value is
          considered managed by macOS and `nix-darwin` will not change it.
        '';
      };

      ignoreShellProgramCheck = mkOption {
        type = types.bool;
        default = false;
        description = ''
          By default, nix-darwin will check that programs.SHELL.enable is set to
          true if the user has a custom shell specified. If that behavior isn't
          required and there are custom overrides in place to make sure that the
          shell is functional, set this to true.
        '';
      };

      packages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        example = literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
        description = ''
          The set of packages that should be made availabe to the user.
          This is in contrast to {option}`environment.systemPackages`,
          which adds packages to all users.
        '';
      };
    };
}
