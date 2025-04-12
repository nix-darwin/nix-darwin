{ config, lib, pkgs, ... }:

with lib;

let
  spacebar = pkgs.runCommand "spacebar-0.0.0" {} "mkdir $out";
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

    conf=`sed -En '/<string>-c<\/string>/{n; s/\s+?<\/?string>//g; p;}' \
      ${config.out}/user/Library/LaunchAgents/org.nixos.spacebar.plist`

    echo >&2 "checking config in $conf"
    grep "spacebar -m config background_color 0xff202020" $conf
    grep "spacebar config loaded..." $conf
  '';
}
