{ config, pkgs, ... }:

let
  cacert = pkgs.runCommand "cacert-0.0.0" {} "mkdir -p $out";
  nix = pkgs.runCommand "nix-2.2" {} "mkdir -p $out";
in

{
  nix.package = nix;
  launchd.labelPrefix = "org.nix-darwin"; # should not have an effect on nix-daemon

  environment.variables.NIX_SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-certificates.crt";

  test = ''
    echo checking nix-daemon service in /Library/LaunchDaemons >&2
    grep "<string>org.nixos.nix-daemon</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "${nix}/bin/nix-daemon</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "<key>KeepAlive</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "<key>PathState</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    (! grep "<key>Sockets</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist)

    echo checking NIX_SSL_CERT_FILE in nix-daemon service >&2
    grep "<key>NIX_SSL_CERT_FILE</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    grep "<string>${cacert}/etc/ssl/certs/ca-certificates.crt</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist

    echo checking nix-daemon reload in /activate >&2
    grep "launchctl kill HUP system/org.nixos.nix-daemon" ${config.out}/activate
  '';
}
