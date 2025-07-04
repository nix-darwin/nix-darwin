{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  nextdns = pkgs.runCommand "nextdns-0.0.0" { } "mkdir $out";

in
{
  services.nextdns.enable = true;
  services.nextdns.arguments = [
    "-config"
    "10.0.3.0/24=abcdef"
  ];

  test = ''
    echo >&2 "checking nextdns service in ~/Library/LaunchDaemons"
    grep "org.nixos.nextdns" ${config.out}/Library/LaunchDaemons/org.nixos.nextdns.plist
    grep "/bin/nextdns" ${config.out}/Library/LaunchDaemons/org.nixos.nextdns.plist
    grep -- "-config" ${config.out}/Library/LaunchDaemons/org.nixos.nextdns.plist
    grep "10.0.3.0/24=abcdef" ${config.out}/Library/LaunchDaemons/org.nixos.nextdns.plist
  '';
}
