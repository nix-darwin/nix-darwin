{ config, lib, ...}:
with lib;
let
  cfg = config.system.autoUpgrade;
  launchdTypes = import ../launchd/types.nix { inherit config lib; };

in

{
  imports = [
    (mkRemovedOptionModule [ "autoUpgrade" "dates" ] "Use `autoUpgrade.interval` instead.")
    (mkRemovedOptionModule [ "autoUpgrade" "fixedRandomDelay" ] "No `nix-darwin` equivalent to this NixOS option.")
    (mkRemovedOptionModule [ "autoUpgrade" "persistent" ] "No `nix-darwin` equivalent to this NixOS option.")
    (mkRemovedOptionModule [ "autoUpgrade" "randomizedDelaySec" ] "No `nix-darwin` equivalent to this NixOS option.")
    (mkRemovedOptionModule [ "autoUpgrade" "reboot" ] "No `nix-darwin` equivalent to this NixOS option.")
    (mkRemovedOptionModule [ "autoUpgrade" "rebootWindow" ] "No `nix-darwin` equivalent to this NixOS option.")
    (mkRemovedOptionModule [ "autoUpgrade" "runGarbageCollection" ] "No `nix-darwin` equivalent to this NixOS option.")
  ];

  options = {
    system.autoUpgrade = {

      enable = mkEnableOption ''
        Whether to periodically upgrade nix-darwin system to the latest
        version. If enabled, a launchd daemon will run
        `darwin-rebuild switch` according to the configured interval.
      '';

      interval = lib.mkOption {
        type = launchdTypes.StartCalendarInterval;
        default = [
          {
            Weekday = 7;
            Hour = 3;
            Minute = 15;
          }
        ];
        description = ''
          The calender interval at which the nix-darwin auto upgrade will run.
          See the {option}`serviceConfig.StartCalendarInterval` option of
          the {option}`launchd` module for more info.
        '';
      };

      operation = lib.mkOption {
        type = lib.types.enum [ "switch" "activate" "build" ];
        default = "switch";
        example = "activate";
        description = ''
          Which operation to run for the auto upgrade. Valid options are
          `switch`, `activate`, or `build`.
        '';
      };

      channel = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "https://github.com/nix-darwin/nix-darwin/archive/master.tar.gz";
        description = ''
          The URI of the nix-darwin channel to use for automatic
          upgrades. By default, this is the channel set using
          {command}`nix-channel` (run `nix-channel --list`
          to see the current value).
        '';
      };

      upgrade = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to run `nix-channel --update` before rebuilding when `channel`
          is set. Set to false when using flakes to honor the
          lockfile, or when using channels but you want to rebuild with the
          current channel version without updating.
        '';
      };

      flake = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "github:sinrohit/nixos-config";
        description = ''
          The Flake URI of the nix-darwin configuration to build.
        '';
      };

      flags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "-I"
          "stuff=/home/alice/nixos-stuff"
          "--option"
          "extra-binary-caches"
          "http://my-cache.example.org/"
        ];
        description = ''
          Any additional flags passed to {command}`darwin-rebuild`.

          If you are using flakes and use a local repo you can add
          {command}`[ "--update-input" "nixpkgs" "--commit-lock-file" ]`
          to update nixpkgs.
        '';
      };

      logDir = mkOption {
        type = types.path;
        default = "/var/log/nix-darwin-upgrade";
        description = "Log directory for Nix Darwin Upgrade";
      };
    };
  };

  config = mkIf cfg.enable {

    assertions = [
      {
        assertion = !((cfg.channel != null) && (cfg.flake != null));
        message = ''
          The options 'system.autoUpgrade.channel' and 'system.autoUpgrade.flake' both cannot be set.
        '';
      }
    ];

    # Disable upgrade when using flakes.
    system.autoUpgrade.upgrade = (cfg.flake == null);

    launchd.daemons.nix-darwin-upgrade = {
      script = let
        flags = (
          if cfg.flake != null then
            [ "--refresh" "--flake" cfg.flake ]
          else
            [ ] ++ lib.optionals (cfg.channel != null) [
              "-I"
              "darwin=${cfg.channel}"
            ]
        ) ++ cfg.flags;
      in ''
        ${lib.optionalString (cfg.upgrade && cfg.channel == null) ''
          ${config.nix.package}/bin/nix-channel --update
        ''}

        ${config.system.build.darwin-rebuild}/bin/darwin-rebuild ${cfg.operation} ${toString flags}
      '';

      serviceConfig = {
        RunAtLoad = false;
        StartCalendarInterval = cfg.interval;
        StandardOutPath = "${cfg.logDir}/nix-darwin-upgrade.log";
        StandardErrorPath = "${cfg.logDir}/nix-darwin-upgrade.log";
      };
    };
  };
}
