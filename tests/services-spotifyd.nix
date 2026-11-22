{ config, extendModules, lib, pkgs, ... }:

with lib;

let
  spotifyd = pkgs.runCommand "spotifyd-0.0.0" {} "mkdir $out";
  withPackagePath = extendModules {
    modules = [ { services.spotifyd.package = lib.mkForce spotifyd.outPath; } ];
  };
in

{
  system.primaryUser = "test-spotify-user";

  services.spotifyd.enable = true;
  services.spotifyd.package = spotifyd;

  test = ''
    echo >&2 "checking spotifyd service in ~/Library/LaunchAgents"
    for system in ${config.out} ${withPackagePath.config.out}; do
      plist="$system/user/Library/LaunchAgents/org.nixos.spotifyd.plist"
      grep -F "org.nixos.spotifyd" "$plist"
      grep -F "${lib.getExe' spotifyd "spotifyd"}" "$plist"
    done
  '';
}
