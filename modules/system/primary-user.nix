{
  lib,
  config,
  ...
}:

{
  options = {
    system.primaryUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The user used for options that previously applied to the user
        running `darwin-rebuild`.

        This is a transition mechanism as nix-darwin reorganizes its
        options and will eventually be unnecessary and removed.
      '';
    };

    system.primaryUserHome = lib.mkOption {
      internal = true;
      type = lib.types.str;
      default =
        config.users.users.${config.system.primaryUser}.home or "/Users/${config.system.primaryUser}";
    };

    system.requiresPrimaryUser = lib.mkOption {
      internal = true;
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = {
    assertions = [
      {
        assertion = config.system.primaryUser == null -> config.system.requiresPrimaryUser == [ ];
        message = ''
          Previously, some nix-darwin options applied to the user running
          `darwin-rebuild`. As part of a long‐term migration to make
          nix-darwin focus on system‐wide activation and support first‐class
          multi‐user setups, all system activation now runs as `root`, and
          these options instead apply to the `system.primaryUser` user.

          You currently have the following primary‐user‐requiring options set:

          ${lib.concatMapStringsSep "\n" (name: "* `${name}`") (
            lib.sort (name1: name2: name1 < name2) config.system.requiresPrimaryUser
          )}

          To continue using these options, set `system.primaryUser` to the name
          of the user you have been using to run `darwin-rebuild`.

          If you run into any unexpected issues with the migration, please
          open an issue at <https://github.com/nix-darwin/nix-darwin/issues/new>
          and include as much information as possible.
        '';
      }
    ];
  };
}
