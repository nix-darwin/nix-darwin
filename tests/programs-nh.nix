{ config, pkgs, ... }:

let
  nh = pkgs.runCommand "nh-0.0.0" { } "mkdir -p $out";
in

{
  programs.nh.enable = true;
  programs.nh.package = nh;
  programs.nh.clean.enable = true;
  programs.nh.clean.user = "nixuser";
  programs.nh.clean.extraArgs = "--keep 5 --keep-since 3d";

  test = ''
    echo checking nh service in /Library/LaunchDaemons >&2
    grep "<string>org.nixos.nh-clean</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist
    grep "<string>/bin/wait4path /nix/store &amp;&amp; exec ${nh}/bin/nh clean all --keep 5 --keep-since 3d</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist
    grep "<key>UserName</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist
    grep "<string>nixuser</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist

    (! grep "<key>KeepAlive</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist)

    echo checking nh validation >&2
    (! grep "programs.nh.clean.user = " ${config.out}/activate-user)
  '';
}
