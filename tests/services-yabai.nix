{ config, lib, pkgs, ... }:

with lib;

let
  yabai = pkgs.runCommand "yabai-0.0.0" {} "mkdir $out";
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

    conf=`sed -En '/<string>-c<\/string>/{n; s/\s+?<\/?string>//g; p;}' \
      ${config.out}/user/Library/LaunchAgents/org.nixos.yabai.plist`

    echo >&2 "checking config in $conf"
    grep "yabai -m config focus_follows_mouse autoraise" $conf
    grep "yabai -m rule --add app='System Preferences' manage=off" $conf
    if [ `cat $conf | wc -l` -eq "2" ]; then echo "yabairc correctly contains 2 lines"; else return 1; fi
  '';
}
