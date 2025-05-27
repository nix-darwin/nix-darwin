# This module defines the packages that appear in
# /run/current-system/sw.
{
  config,
  lib,
  pkgs,
  ...
}:
let

  makeDrvBinPath = lib.concatMapStringsSep ":" (p: if lib.isDerivation p then "${p}/bin" else p);

  defaultPackageNames = [ ];
  defaultPackages = map (
    n:
    let
      pkg = pkgs.${n};
    in
    lib.setPrio ((pkg.meta.priority or lib.meta.defaultPriority) + 3) pkg
  ) defaultPackageNames;
  defaultPackagesText = "[ ${lib.concatMapStringsSep " " (n: "pkgs.${n}") defaultPackageNames} ]";

in

{
  imports = [
    (lib.mkRenamedOptionModule ["environment" "postBuild"] ["environment" "extraSetup"])
  ];

  options = {

    environment = {
      systemPath = lib.mkOption {
        type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
        description = "The set of paths that are added to PATH.";
        apply = x: if lib.isList x then makeDrvBinPath x else x;
      };

      systemPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        example = lib.literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
        description = ''
          The set of packages that appear in
          /run/current-system/sw.  These packages are
          automatically available to all users, and are
          automatically updated every time you rebuild the system
          configuration.  (The latter is the main difference with
          installing them in the default profile,
          {file}`/nix/var/nix/profiles/default`.
        '';
      };

      defaultPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = defaultPackages;
        defaultText = lib.literalMD ''
          these packages, with their `meta.priority` numerically increased
          (thus lowering their installation priority):

              ${defaultPackagesText}
        '';
        example = [ ];
        description = ''
          Set of default packages that aren't strictly necessary
          for a running system, entries can be removed for a more
          minimal NixOS installation.

          Like with systemPackages, packages are installed to
          {file}`/run/current-system/sw`. They are
          automatically available to all users, and are
          automatically updated every time you rebuild the system
          configuration.
        '';
      };

      pathsToLink = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        # According to https://github.com/NixOS/nixpkgs/blob/2795c506fe8fb7b03c36ccb51f75b6df0ab2553f/nixos/modules/config/system-path.nix#L108-L109
        # `/lib` needs to be added to make NSS modules work, however currently we don't add it
        # and it's unclear whether the comment applies on macOS as well.
        default = [ ];
        example = [ "/share/doc" ];
        description = "List of directories to be symlinked in {file}`/run/current-system/sw`.";
      };

      extraOutputsToInstall = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [
          "dev"
          "info"
        ];
        description = ''
          Entries listed here will be appended to the `meta.outputsToInstall` attribute for each package in `environment.systemPackages`, and the files from the corresponding derivation outputs symlinked into {file}`/run/current-system/sw`.

          For example, this can be used to install the `dev` and `info` outputs for all packages in the system environment, if they are available.

          To use specific outputs instead of configuring them globally, select the corresponding attribute on the package derivation, e.g. `libxml2.dev` or `coreutils.info`.
        '';
      };

      extraSetup = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Shell fragments to be run after the system environment has been created. This should only be used for things that need to modify the internals of the environment, e.g. generating MIME caches. The environment being built can be accessed at $out.";
      };

    };

    system = {

      path = lib.mkOption {
        internal = true;
        description = ''
          The packages you want in the system environment.
        '';
      };

    };

  };

  config = {

    environment.systemPackages = config.environment.defaultPackages;

    environment.pathsToLink = [
      "/bin"
      "/share/locale"
    ];

    system.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      inherit (config.environment) pathsToLink extraOutputsToInstall;
      ignoreCollisions = true;
      # !!! Hacky, should modularise.
      # outputs TODO: note that the tools will often not be linked by default
      postBuild = ''
        # Remove wrapped binaries, they shouldn't be accessible via PATH.
        find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete

        ${config.environment.extraSetup}
      '';
    };

  };
}
