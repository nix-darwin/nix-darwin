{ lib, pkgs, ... }:

let
  configuration = import ../eval-config.nix {
    inherit lib;
    modules = [
      {
        nixpkgs.source = pkgs.path;
        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform;
        system.stateVersion = 7;
        system.primaryUser = "test";
        users.knownUsers = [ "test" ];
        users.users.test = {
          home = "/Users/test";
          uid = 501;
        };
      }
    ];
  };
in
{
  test = builtins.deepSeq configuration.config.assertions ''
    true
  '';
}
