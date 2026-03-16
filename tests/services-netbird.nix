{ config, pkgs, ... }:

let
  netbird = pkgs.runCommand "netbird-0.0.0" { meta.mainProgram = "netbird"; } ''
    mkdir -p $out/bin
    touch $out/bin/netbird
    chmod +x $out/bin/netbird
  '';
in
{
  services.netbird = {
    enable = true;
    package = netbird;
    clients.corp.interface = "utun101";
  };

  test = ''
    echo >&2 "checking default netbird daemon in /Library/LaunchDaemons"
    grep "org.nixos.netbird" ${config.out}/Library/LaunchDaemons/org.nixos.netbird.plist
    grep "utun100" ${config.out}/Library/LaunchDaemons/org.nixos.netbird.plist
    grep "/var/lib/netbird/config.json" ${config.out}/Library/LaunchDaemons/org.nixos.netbird.plist
    grep "/var/log/netbird.out.log" ${config.out}/Library/LaunchDaemons/org.nixos.netbird.plist
    grep "/var/log/netbird.err.log" ${config.out}/Library/LaunchDaemons/org.nixos.netbird.plist

    echo >&2 "checking netbird-corp daemon in /Library/LaunchDaemons"
    grep "org.nixos.netbird-corp" ${config.out}/Library/LaunchDaemons/org.nixos.netbird-corp.plist
    grep "utun101" ${config.out}/Library/LaunchDaemons/org.nixos.netbird-corp.plist
    grep "/var/lib/netbird-corp/config.json" ${config.out}/Library/LaunchDaemons/org.nixos.netbird-corp.plist
    grep "unix:///var/run/netbird-corp/sock" ${config.out}/Library/LaunchDaemons/org.nixos.netbird-corp.plist
    grep "/var/log/netbird-corp.out.log" ${config.out}/Library/LaunchDaemons/org.nixos.netbird-corp.plist
    grep "/var/log/netbird-corp.err.log" ${config.out}/Library/LaunchDaemons/org.nixos.netbird-corp.plist
  '';
}
