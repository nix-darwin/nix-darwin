{ config, pkgs, ... }:

let
  nix = pkgs.runCommand "nix-2.2" { pname = "nix"; } "mkdir -p $out";
in

{
  services.nix-daemon.enableSocketListener = true;
  nix.package = nix;
  launchd.labelPrefix = "org.nix-darwin"; # should not have an effect on nix-daemon

  test = ''
    echo checking nix-daemon service in /Library/LaunchDaemons >&2
    grep "<string>org.nixos.nix-daemon</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "<string>/bin/wait4path" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "&amp;&amp;" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "exec ${nix}/bin/nix-daemon</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    (! grep "<key>KeepAlive</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist)
    grep "<key>Sockets</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "/nix/var/nix/daemon-socket/socket" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
  '';
}
