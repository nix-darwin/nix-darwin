{ config, pkgs, ... }:

let
  autoraise = pkgs.runCommand "autoraise-0.0.0" { } "mkdir $out";
in

{
  services.autoraise.enable = true;
  services.autoraise.package = autoraise;
  services.autoraise.settings = {
    pollMillis = 50;
    delay = 1;
    focusDelay = 0;
    warpX = 0.5;
    warpY = 0.1;
    scale = 2.5;
    altTaskSwitcher = false;
    ignoreSpaceChanged = false;
    invertIgnoreApps = false;
    ignoreApps = [
      "IntelliJ IDEA"
      "WebStorm"
    ];
    ignoreTitles = [ "\\s\\| Microsoft Teams" ];
    stayFocusedBundleIds = [ "com.apple.SecurityAgent" ];
    disableKey = "control";
    mouseDelta = 0.1;
  };

  test = ''
    echo >&2 "checking autoraise service in ~/Library/LaunchAgents"
    grep "org.nixos.autoraise" ${config.out}/user/Library/LaunchAgents/org.nixos.autoraise.plist
    grep "${autoraise}/Applications/AutoRaise.app/Contents/MacOS/AutoRaise" ${config.out}/user/Library/LaunchAgents/org.nixos.autoraise.plist

    conf=`sed -En 's/^[[:space:]]*<string>.*AutoRaise (.*)<\/string>$/\1/p' \
      ${config.out}/user/Library/LaunchAgents/org.nixos.autoraise.plist`

    echo >&2 "checking config flags"
    if [[ "$conf" != '-altTaskSwitcher false -delay 1 -disableKey "control" -focusDelay 0 -ignoreApps "IntelliJ IDEA,WebStorm" -ignoreSpaceChanged false -ignoreTitles "\s\| Microsoft Teams" -invertIgnoreApps false -mouseDelta 0.100000 -pollMillis 50 -scale 2.500000 -stayFocusedBundleIds "com.apple.SecurityAgent" -warpX 0.500000 -warpY 0.100000' ]]; then
      echo >&2 "unexpected config flags: $conf"
      exit 1
    fi
  '';
}
