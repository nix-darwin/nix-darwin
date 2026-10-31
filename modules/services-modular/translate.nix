# Portable serviceSubmodule -> launchd entry translation, shared between
# the system (`launchd.daemons`) and user (`launchd.user.agents`) trees.
{ lib }:
let
  inherit (lib)
    concatMapAttrs
    optionalAttrs
    ;

  dash =
    before: after:
    if after == "" then before
    else if before == "" then after
    else "${before}-${after}";

  toServiceConfig = { kind, service }:
    let
      inherit (service) process processConfig;
      cfg = processConfig;
      argv = process.argv or [ ];
      darwinExtras = service.launchd or { };
    in
    (optionalAttrs (argv != [ ]) {
      ProgramArguments = argv;
    })
    // (optionalAttrs (kind == "daemon" && cfg.user != null) {
      UserName = cfg.user;
    })
    // (optionalAttrs (kind == "daemon" && cfg.group != null) {
      GroupName = cfg.group;
    })
    // (optionalAttrs (cfg.workingDirectory != null) {
      WorkingDirectory = cfg.workingDirectory;
    })
    // (optionalAttrs (cfg.environment != { }) {
      EnvironmentVariables = cfg.environment;
    })
    // (optionalAttrs (cfg.standardOutput != null) {
      StandardOutPath = cfg.standardOutput;
    })
    // (optionalAttrs (cfg.standardError != null) {
      StandardErrorPath = cfg.standardError;
    })
    // darwinExtras;

  # Walk a service (and its sub-services) producing a flat attrset of
  # launchd-entry configs keyed by dashed service path.
  flatten = { kind }:
    let
      go = prefix: service:
        {
          ${prefix} = {
            serviceConfig = toServiceConfig { inherit kind service; };
          };
        }
        // concatMapAttrs (n: sub: go (dash prefix n) sub) (service.services or { });
    in
    go;
in
{
  inherit dash flatten toServiceConfig;
}
