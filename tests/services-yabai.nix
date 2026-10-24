{ config, lib, pkgs, ... }:

with lib;

let
  yabai = pkgs.writeShellScriptBin "yabai" ''
    set -eu
    test "$#" -eq 2
    test "$1" = -c
    ${pkgs.coreutils}/bin/cat "$2"
  '';
in

{
  system.primaryUser = "test-yabai-user";

  services.yabai.enable = true;
  services.yabai.package = yabai;
  services.yabai.config = { focus_follows_mouse = "autoraise"; };
  services.yabai.extraConfig = "yabai -m rule --add app='System Preferences' manage=off";

  test = ''
    echo >&2 "checking yabai service in ~/Library/LaunchAgents"
    grep "org.nixos.yabai" ${config.out}/user/Library/LaunchAgents/org.nixos.yabai.plist
    grep "${yabai}/bin/yabai" ${config.out}/user/Library/LaunchAgents/org.nixos.yabai.plist

    echo >&2 "checking the config passed to yabai"
    ${pkgs.python3}/bin/python ${./run-launchd.py} \
      ${config.out}/user/Library/LaunchAgents/org.nixos.yabai.plist > actual-config

    grep "yabai -m config focus_follows_mouse autoraise" actual-config
    grep "yabai -m rule --add app='System Preferences' manage=off" actual-config
  '';
}
