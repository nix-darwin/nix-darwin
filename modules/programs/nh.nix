{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nh;
in

with lib;

{
  options.programs.nh = {
    enable = mkEnableOption "nh, yet another Nix CLI helper";

    package = mkPackageOption pkgs "nh" { };

    flake = mkOption {
      type = with types; nullOr str;
      default = null;
      description = ''
        The path that will be used for the `NH_DARWIN_FLAKE` environment variable.

        `NH_DARWIN_FLAKE` is used by nh as the default flake for performing actions, like
        `nh darwin switch`. This must be a path to a directory containing a nix flake, not
        the `flake.nix` file itself.
      '';
    };

    clean = {
      enable = mkEnableOption "Periodic garbage collection with `nh clean all`.";

      dates = mkOption {
        type = with types; listOf (attrsOf types.int);
        default = [
          {
            Minute = 0;
            Hour = 0;
            Weekday = 1;
          }
        ];
        description = ''
          How often cleanup is performed. Passed to launchd.

          The format is described in
          {manpage}`launchd.plist(5)`.
        '';
      };

      extraArgs = mkOption {
        type = types.singleLineStr;
        default = "";
        example = "--keep 5 --keep-since 3d";
        description = ''
          Options given to nh clean when the service is run automatically.

          See `nh clean all --help` for more information.
        '';
      };
    };
  };

  config = {
    warnings = optionals (!(cfg.clean.enable -> !config.nix.gc.automatic)) [
      "programs.nh.clean.enable and nix.gc.automatic are both enabled. Please use one or the other to avoid conflict."
    ];

    assertions = [
      {
        assertion = cfg.clean.enable -> cfg.enable;
        message = "`programs.nh.clean.enable` requires programs.nh.enable";
      }

      {
        assertion = (cfg.flake != null) -> !(hasSuffix ".nix" cfg.flake);
        message = "`programs.nh.flake` must be a directory, not a nix file";
      }
    ];

    environment = mkIf cfg.enable {
      systemPackages = [ cfg.package ];
      variables = optionalAttrs { NH_FLAKE = cfg.flake; };
    };

    launchd.daemons = mkIf cfg.clean.enable {
      "nh-clean" = {
        command = "${getExe cfg.package} clean all ${cfg.clean.extraArgs}";

        environment.NH_FLAKE = optionalString (cfg.flake != null) cfg.flake;

        serviceConfig = {
          RunAtLoad = false;
          StartCalendarInterval = cfg.clean.dates;
        };
      };
    };
  };
}
