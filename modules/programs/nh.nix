# Based off: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/nh.nix
# When making changes please try to keep it in sync.
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.programs.nh;
in
{
  meta.maintainers = [
    maintainers.alanpearce or "alanpearce"
  ];

  imports = [
    (mkRemovedOptionModule [ "programs" "nh" "clean" "dates" ] "Use `programs.nh.clean.interval` instead.")
  ];

  options.programs.nh = {
    enable = mkEnableOption "nh, yet another Nix CLI helper";

    package = mkPackageOption pkgs "nh" { };

    flake = mkOption {
      type = with types; nullOr (either singleLineStr path);
      default = null;
      description = ''
        The path that will be used for the `NH_FLAKE` environment variable.

        `NH_FLAKE` is used by nh as the default flake for performing actions, like `nh os switch`.
      '';
    };

    clean = {
      enable = mkEnableOption "periodic garbage collection with nh clean all";

      # Not in NixOS module
      user = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "User that runs the garbage collector.";
      };

      interval = mkOption {
        type = types.attrs;
        default = { Hour = 3; Minute = 15; };
        description = ''
          How often cleanup is performed.

          The format is described in
          {manpage}`launchd.plist(5)`.
        '';
      };

      extraArgs = mkOption {
        type = types.singleLineStr;
        default = "";
        example = "--keep 5 --keep-since 3d";
        description = ''
          Options given to {file}`nh` clean when the service is run automatically.

          See {file}`nh clean all --help` for more information.
        '';
      };
    };
  };

  config = {
    warnings =
      if (!(cfg.clean.enable -> !config.nix.gc.automatic)) then [
        "programs.nh.clean.enable and nix.gc.automatic are both enabled. Please use one or the other to avoid conflict."
      ] else [ ];

    assertions = [
      # Not strictly required but probably a good assertion to have
      {
        assertion = cfg.clean.enable -> cfg.enable;
        message = "programs.nh.clean.enable requires programs.nh.enable";
      }

      {
        assertion = (cfg.flake != null) -> !(hasSuffix ".nix" cfg.flake);
        message = "nh.flake must be a directory, not a nix file";
      }
    ];

    environment = mkIf cfg.enable {
      systemPackages = [ cfg.package ];
      variables = mkIf (cfg.flake != null) {
        NH_FLAKE = cfg.flake;
      };
    };

    launchd = mkIf cfg.clean.enable {
      daemons.nh-clean = {
        command = "${getExe cfg.package} clean all ${cfg.clean.extraArgs}";
        serviceConfig = {
          RunAtLoad = false;
          StartCalendarInterval = [ cfg.clean.interval ];
          UserName = cfg.clean.user;
        };
        path = [ config.nix.package ];
      };
    };
  };
}
