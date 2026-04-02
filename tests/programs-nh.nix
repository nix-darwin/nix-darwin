{ config, pkgs, ... }:

let
  nix = pkgs.runCommand "nix-2.2" { } "mkdir -p $out";
  nh = pkgs.runCommand "nh" { } "mkdir -p $out";
in

{
  programs.nh.enable = true;
  programs.nh.package = nh;
  programs.nh.clean.enable = true;
  programs.nh.clean.extraArgs = "--keep 5 --keep-since 3d";
  nix.package = nix;

  test = ''
    echo checking nh-clean service in /Library/LaunchDaemons >&2
    grep "<string>${nix}/bin</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist
    grep "<string>org.nixos.nh-clean</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist
    grep "<string>/bin/wait4path /nix/store &amp;&amp; exec ${nh}/bin/nh clean all --keep 5 --keep-since 3d</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist

    (! grep "<key>KeepAlive</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist)
  '';
}
