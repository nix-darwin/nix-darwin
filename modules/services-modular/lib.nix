# Wraps `lib/services.configure` from nixpkgs so both the system- and
# user-side modular service trees are constructed the same way.
{ lib, pkgs, rootPath, extraRootModules ? [ ] }:
let
  servicesLib = import "${pkgs.path}/lib/services/lib.nix" { inherit lib; };

  configured = servicesLib.configure {
    serviceManagerPkgs = pkgs;
    extraRootModules = [
      ./extra-root.nix
      (import ./config-data.nix { inherit rootPath; })
    ] ++ extraRootModules;
  };
in
{
  inherit (configured) serviceSubmodule;
  inherit (servicesLib) getAssertions getWarnings;
}
