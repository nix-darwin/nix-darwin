{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  _class = "service";

  options = {
    processConfig = mkOption {
      default = { };
      type = types.submodule {
        options = {
          user = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              User to run the service as. Translated to launchd
              `UserName`. Only honored for system services
              (LaunchDaemons); for user agents an assertion is raised
              if a value other than `null` is supplied.
            '';
          };
          group = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Group to run the service as. Translated to launchd
              `GroupName`. Only honored for system services.
            '';
          };
          workingDirectory = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Translated to launchd `WorkingDirectory`.";
          };
          environment = mkOption {
            type = types.attrsOf types.str;
            default = { };
            description = ''
              Environment variables passed to the service. Merged
              into launchd `EnvironmentVariables`.
            '';
          };
          standardOutput = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Path of the file to which standard output is
              redirected. Translated to launchd `StandardOutPath`.
            '';
          };
          standardError = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Path of the file to which standard error is
              redirected. Translated to launchd `StandardErrorPath`.
            '';
          };
        };
      };
    };

    launchd = mkOption {
      default = { };
      type = types.submodule {
        freeformType = types.attrsOf types.unspecified;
      };
      description = ''
        Free-form launchd plist keys merged verbatim into the generated
        plist. This is the platform escape hatch for anything that has no
        portable analogue (for example `StartCalendarInterval` or
        `LimitLoadToSessionType`).

        Mirrors the `systemd.*` namespace on NixOS: upstream service modules
        guard these keys with
        `lib.optionalAttrs (options ? systemd) { systemd.* = ...; }`, and the
        same pattern applies here with `launchd` in place of `systemd`.
      '';
    };

    # Recurse this extension into sub-services so the same options are
    # available at every depth.
    services = mkOption {
      type = types.attrsOf (
        types.submoduleWith {
          class = "service";
          modules = [ ./extra-root.nix ];
        }
      );
    };
  };
}
