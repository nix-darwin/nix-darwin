{ config, pkgs, ... }:
let
  jpeg = '''';
in
{
  system.primaryUser = "test-system-wallpaper-user";
  system.wallpaper.enable = true;
  system.wallpaper.path = ./fixtures/system-wallpaper/image.jpeg;

  test = ''
    plist=${config.out}/user/Library/LaunchAgents/org.nixos.wallpaper.plist
    echo >&2 "testing for wallpaper launchAction"
    test -f $plist

    echo >&2 "testing for wallpaper script in launchAction"
    grep -q '<string>/bin/wait4path /nix/store &amp;&amp; exec /nix/store/.*' $plist
  '';
}
