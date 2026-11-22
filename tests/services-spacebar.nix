{ config, extendModules, lib, pkgs, ... }:

with lib;

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
  spacebar = pkgs.writeShellScriptBin "spacebar" ''
    [[ $# == 2 && $1 == -c ]] || exit 1
    cat "$2"
  '';
  withPackagePath = extendModules {
    modules = [ { services.spacebar.package = lib.mkForce spacebar.outPath; } ];
  };
in

{
  system.primaryUser = "test-spacebar-user";

  services.spacebar.enable = true;
  services.spacebar.package = spacebar;
  services.spacebar.config = { background_color = "0xff202020"; };
  services.spacebar.extraConfig = ''echo "spacebar config loaded..."'';

  test = ''
    echo >&2 "checking spacebar service in ~/Library/LaunchAgents"
    grep "org.nixos.spacebar" ${config.out}/user/Library/LaunchAgents/org.nixos.spacebar.plist
    grep -F "${lib.getExe spacebar}" ${config.out}/user/Library/LaunchAgents/org.nixos.spacebar.plist

    ${runJob config.launchd.user.agents.spacebar} > spacebarrc
    grep -F "spacebar -m config background_color 0xff202020" spacebarrc
    grep -F "spacebar config loaded..." spacebarrc

    ${runJob withPackagePath.config.launchd.user.agents.spacebar} > spacebarrc-from-path
    cmp spacebarrc spacebarrc-from-path
  '';
}
