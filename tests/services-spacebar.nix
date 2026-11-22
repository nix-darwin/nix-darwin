{ config, lib, pkgs, ... }:

with lib;

let
  spacebar = pkgs.writeShellScriptBin "spacebar" ''
    set -eu
    test "$#" -eq 2
    test "$1" = -c
    ${pkgs.coreutils}/bin/cat "$2"
  '';
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
    grep "${spacebar}/bin/spacebar" ${config.out}/user/Library/LaunchAgents/org.nixos.spacebar.plist

    echo >&2 "checking the config passed to spacebar"
    ${pkgs.python3}/bin/python ${./run-launchd.py} \
      ${config.out}/user/Library/LaunchAgents/org.nixos.spacebar.plist > actual-config

    grep "spacebar -m config background_color 0xff202020" actual-config
    grep "spacebar config loaded..." actual-config
  '';
}
