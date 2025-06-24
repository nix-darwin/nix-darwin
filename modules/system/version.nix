{ options, config, lib, ... }:

with lib;

let
  cfg = config.system;

  # Based on `lib.trivial.revisionWithDefault` from nixpkgs.
  gitRevision = path:
    if pathIsGitRepo "${path}/.git"
    then commitIdFromGitRepo "${path}/.git"
    else if pathExists "${path}/.git-revision"
    then fileContents "${path}/.git-revision"
    else null;

  nixpkgsSrc = config.nixpkgs.source;

  # If `nixpkgs.constructedByUs` is true, then Nixpkgs was imported from
  # `nixpkgs.source` and we can use revision information (flake input,
  # `builtins.fetchGit`, etc.) from it. Otherwise `pkgs` could be
  # anything and we can't reliably determine exact version information,
  # but if the configuration explicitly sets `nixpkgs.source` we
  # trust it.
  useSourceRevision =
    (config.nixpkgs.constructedByUs
      || options.nixpkgs.source.highestPrio < (lib.mkDefault {}).priority)
    && isAttrs nixpkgsSrc
    && (nixpkgsSrc._type or null == "flake"
      || isString (nixpkgsSrc.rev or null));
in

{
  options = {
    system.stateVersion = mkOption {
      type = types.ints.between 1 config.system.maxStateVersion;
      # TODO: Remove this default and the assertion below.
      default = config.system.maxStateVersion;
      description = ''
        Every once in a while, a new nix-darwin release may change
        configuration defaults in a way incompatible with stateful
        data. For instance, if the default version of PostgreSQL
        changes, the new version will probably be unable to read your
        existing databases. To prevent such breakage, you can set the
        value of this option to the nix-darwin release with which you want
        to be compatible. The effect is that nix-darwin will option
        defaults corresponding to the specified release (such as using
        an older version of PostgreSQL).
      '';
    };

    system.maxStateVersion = mkOption {
      internal = true;
      type = types.int;
      default = 6;
    };

    system.darwinLabel = mkOption {
      type = types.str;
      description = "Label to be used in the names of generated outputs.";
    };

    system.darwinRelease = mkOption {
      readOnly = true;
      type = types.str;
      default = (lib.importJSON ../../version.json).release;
      description = "The nix-darwin release (e.g. `24.11`).";
    };

    system.darwinVersion = mkOption {
      internal = true;
      type = types.str;
      default = cfg.darwinRelease + cfg.darwinVersionSuffix;
      description = "The full nix-darwin version (e.g. `24.11.2abdb5a`).";
    };

    system.darwinVersionSuffix = mkOption {
      internal = true;
      type = types.str;
      default = if cfg.darwinRevision != null
        then ".${substring 0 7 cfg.darwinRevision}"
        else "";
      description = "The short nix-darwin version suffix (e.g. `.2abdb5a`).";
    };

    system.darwinRevision = mkOption {
      internal = true;
      type = types.nullOr types.str;
      default = gitRevision (toString ../..);
      description = "The darwin git revision from which this configuration was built.";
    };

    system.nixpkgsRelease = mkOption {
      readOnly = true;
      type = types.str;
      default = lib.trivial.release;
      description = "The nixpkgs release (e.g. `24.11`).";
    };

    # TODO: Shouldn’t mismatch the Darwin release, rethink all this…
    system.nixpkgsVersion = mkOption {
      internal = true;
      type = types.str;
      default = cfg.nixpkgsRelease + cfg.nixpkgsVersionSuffix;
      description = "The full nixpkgs version (e.g. `24.11.1160.f2d4ee1`).";
    };

    system.nixpkgsVersionSuffix = mkOption {
      internal = true;
      type = types.str;
      default = if useSourceRevision
        then ".${lib.substring 0 8 (nixpkgsSrc.lastModifiedDate or nixpkgsSrc.lastModified or "19700101")}.${nixpkgsSrc.shortRev or "dirty"}"
        else lib.trivial.versionSuffix;
      description = "The short nixpkgs version suffix (e.g. `.1160.f2d4ee1`).";
    };

    system.nixpkgsRevision = mkOption {
      internal = true;
      type = types.nullOr types.str;
      default = if useSourceRevision && nixpkgsSrc ? rev
        then nixpkgsSrc.rev
        else lib.trivial.revisionWithDefault null;
      description = "The nixpkgs git revision from which this configuration was built.";
    };

    system.configurationRevision = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The Git revision of the top-level flake from which this configuration was built.";
    };
  };

  config = {
    # This default is set here rather than up there so that the options
    # documentation is not reprocessed on every commit
    system.darwinLabel = mkDefault cfg.darwinVersion;

    assertions = [
      {
        assertion = options.system.stateVersion.highestPrio != (lib.mkOptionDefault { }).priority;
        message = ''
          The `system.stateVersion` option is not defined in your
          nix-darwin configuration. The value is used to conditionalize
          backwards‐incompatible changes in default settings. You should
          usually set this once when installing nix-darwin on a new system
          and then never change it (at least without reading all the relevant
          entries in the changelog using `darwin-rebuild changelog`).

          You can use the current value for new installations as follows:

              system.stateVersion = ${toString config.system.maxStateVersion};
        '';
      }
    ];
  };
}
