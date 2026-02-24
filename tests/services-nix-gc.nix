{ config, pkgs, ... }:

let
  nix = pkgs.runCommand "nix-2.2" { pname = "nix"; } "mkdir -p $out";
in

{
  nix.gc.automatic = true;
  nix.gc.options = "--delete-older-than 30d";
  nix.package = nix;

  test = ''
    echo checking nix-gc service in /Library/LaunchDaemons >&2
    grep "<string>org.nixos.nix-gc</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-gc.plist
    grep "<string>/bin/wait4path /nix/store &amp;&amp; exec ${nix}/bin/nix-collect-garbage --delete-older-than 30d</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-gc.plist

    (! grep "<key>KeepAlive</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-gc.plist)
  '';
}
