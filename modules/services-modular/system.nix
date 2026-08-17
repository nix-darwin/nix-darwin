{ config, lib, pkgs, ... }:
let
  inherit (lib) concatMapAttrs mapAttrs' mkOption types;

  rootPath = "/etc/system-services";

  servicesLib = import ./lib.nix { inherit lib pkgs rootPath; };
  translate = import ./translate.nix { inherit lib; };

  # configData entries surface as etc files at the path computed by
  # config-data.nix (e.g. /etc/system-services/<prefix>/<name>).
  makeEtcFiles =
    prefix: service:
    let
      ownEntries = mapAttrs' (_: cfg: {
        name = lib.removePrefix "/etc/" cfg.path;
        value = { inherit (cfg) enable source; };
      }) (lib.filterAttrs (_: cfg: cfg.enable) (service.configData or { }));

      subEntries = concatMapAttrs (
        n: sub: makeEtcFiles (translate.dash prefix n) sub
      ) (service.services or { });
    in
    ownEntries // subEntries;

  daemonEntries = topName: top:
    translate.flatten { kind = "daemon"; } topName top;
in
{
  options.system.services = mkOption {
    type = types.attrsOf servicesLib.serviceSubmodule;
    default = { };
    description = ''
      Modular services run as system LaunchDaemons.

      The submodule schema is the portable one defined by nixpkgs'
      `lib/services` plus a darwin-specific `processConfig` namespace
      and a `launchd` escape hatch for native launchd plist keys.
      See the `modules/services-modular` directory.
    '';
    visible = "shallow";
  };

  config = {
    launchd.daemons = concatMapAttrs (
      n: service: daemonEntries n service
    ) config.system.services;

    environment.etc = concatMapAttrs (
      n: service: makeEtcFiles n service
    ) config.system.services;

    assertions = lib.concatLists (
      lib.mapAttrsToList (
        n: service: servicesLib.getAssertions [ "system" "services" n ] service
      ) config.system.services
    );

    warnings = lib.concatLists (
      lib.mapAttrsToList (
        n: service: servicesLib.getWarnings [ "system" "services" n ] service
      ) config.system.services
    );
  };
}
