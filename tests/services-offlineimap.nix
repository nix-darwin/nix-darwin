{ config, lib, pkgs, ... }:

with lib;

let
  offlineimap = pkgs.runCommand "offlineimap-0.0.0" {} "mkdir -p $out";
in

{
  system.primaryUser = "test-offlineimap-user";

  services.offlineimap.enable = true;
  services.offlineimap.package = offlineimap;
  services.offlineimap.runQuick = true;
  services.offlineimap.extraConfig = ''
    [general]
    accounts = test
    ui = quiet

    [Account test]
    localrepository = testLocal
    remoterepository = testRemote
    autorefresh = 2
    maxage = 2017-07-01

    [Repository testLocal]
    type = GmailMaildir

    [Repository testRemote]
    type = Gmail
    ssl = yes
    starttls = no
    expunge = yes
  '';

  test = ''
    echo >&2 "checking offlineimap service in ~/Library/LaunchAgents"
    grep "org.nixos.offlineimap" ${config.out}/user/Library/LaunchAgents/org.nixos.offlineimap.plist
    grep "bin/offlineimap" ${config.out}/user/Library/LaunchAgents/org.nixos.offlineimap.plist
    grep "\-q" ${config.out}/user/Library/LaunchAgents/org.nixos.offlineimap.plist

    echo >&2 "checking config in /etc/offlineimaprc"
    grep "accounts\ \=\ test" ${config.out}/etc/offlineimaprc
  '';
}
