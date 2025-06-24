{ config, lib, pkgs, ... }:

with lib;

let
  jankyborders = pkgs.runCommand "borders-0.0.0" {} "mkdir $out";
in

{
  system.primaryUser = "test-jankyborders-user";

  services.jankyborders.enable = true;
  services.jankyborders.package = jankyborders;
  services.jankyborders.width = 5.0;
  services.jankyborders.hidpi = true;
  services.jankyborders.active_color = "0xFFFFFFFF";
  services.jankyborders.order = "below";

  test = ''
    echo >&2 "checking jankyborders service in ~/Library/LaunchAgents"
    grep "org.nixos.jankyborders" ${config.out}/user/Library/LaunchAgents/org.nixos.jankyborders.plist
    grep "${jankyborders}/bin/borders" ${config.out}/user/Library/LaunchAgents/org.nixos.jankyborders.plist

    echo >&2 "checking jankyborders config arguments"
    grep "width=5.000000" ${config.out}/user/Library/LaunchAgents/org.nixos.jankyborders.plist
    grep "hidpi=on" ${config.out}/user/Library/LaunchAgents/org.nixos.jankyborders.plist
    grep "active_color=0xFFFFFFFF" ${config.out}/user/Library/LaunchAgents/org.nixos.jankyborders.plist
    grep "order=below" ${config.out}/user/Library/LaunchAgents/org.nixos.jankyborders.plist
  '';
}
