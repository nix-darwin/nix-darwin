{ config, pkgs, lib, ... }:

let
  nix-tools = pkgs.callPackage ../../pkgs/nix-tools {
    inherit (config.system) profile;
    inherit (config.environment) systemPath;
    nixPath = lib.optionalString config.nix.enable (lib.concatStringsSep ":" config.nix.nixPath);
    nixPackage = if config.nix.enable then config.nix.package else null;
  };

  darwin-uninstaller = pkgs.callPackage ../../pkgs/darwin-uninstaller { };

  mkToolModule = { name, package ? nix-tools.${name} }: { config, ... }: {
    options.system.tools.${name}.enable = lib.mkEnableOption "${name} script" // {
      default = config.system.tools.enable;
    };

    config = lib.mkIf config.system.tools.${name}.enable {
      environment.systemPackages = [ package ];
    };
  };
in

{
  options.system = {
    tools.enable = lib.mkOption {
      type = lib.types.bool;
      internal = true;
      default = true;
      description = ''
        Disable internal tools, such as darwin-rebuild and darwin-option. This
        is useful to shrink systems which are not expected to rebuild or
        reconfigure themselves. Use at your own risk!
    '';
    };
  };

  imports = [
    (lib.mkRenamedOptionModule [ "system" "includeUninstaller" ] [ "system" "tools" "darwin-uninstaller" "enable" ])
    (lib.mkRemovedOptionModule [ "system" "disableInstallerTools" ] "Please use system.tools.enable instead")

    (mkToolModule { name = "darwin-option"; })
    (mkToolModule { name = "darwin-rebuild"; })
    (mkToolModule { name = "darwin-version"; })
    (mkToolModule { name = "darwin-uninstaller"; package = darwin-uninstaller; })
  ];

  config = {
    system.build = {
      inherit (nix-tools) darwin-option darwin-rebuild darwin-version;
    };
  };
}
