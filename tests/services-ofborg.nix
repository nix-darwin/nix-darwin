{ config, pkgs, ... }:

let
  ofborg = pkgs.runCommand "ofborg-0.0.0" {} "mkdir $out";
in

{
  services.ofborg.enable = true;
  services.ofborg.package = ofborg;

  users.knownGroups = [ "ofborg" ];
  users.knownUsers = [ "ofborg" ];

  test = ''
    echo >&2 "checking ofborg service in /Library/LaunchDaemons"
    grep "org.nixos.ofborg" ${config.out}/Library/LaunchDaemons/org.nixos.ofborg.plist
    grep "<string>ofborg</string>" ${config.out}/Library/LaunchDaemons/org.nixos.ofborg.plist

    echo >&2 "checking for user in /activate"
    grep "OfBorg service user" ${config.out}/activate

    echo >&2 "checking for logfile permissions in /activate"
    grep "touch '/var/log/ofborg.log'" ${config.out}/activate
    grep "chown .* '/var/log/ofborg.log'" ${config.out}/activate

    echo >&2 "checking config.json permissions in /activate"
    grep "chmod 600 '/private/var/lib/ofborg/config.json'" ${config.out}/activate
    grep "chown .* '/private/var/lib/ofborg/config.json'" ${config.out}/activate
  '';
}
