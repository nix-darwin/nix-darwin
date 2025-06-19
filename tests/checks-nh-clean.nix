{ config, pkgs, ... }:

let
  nh = pkgs.runCommand "nh-0.0.0" { } "mkdir -p $out";
in

{
  programs.nh.enable = true;
  programs.nh.package = nh;
  programs.nh.clean.enable = true;

  test = ''
    echo checking nh-clean validation >&2
    grep "programs.nh.clean.user = " ${config.out}/activate-user

    echo checking nh-clean service in /Library/LaunchDaemons >&2
    grep "<string>org.nixos.nh-clean</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist
    (! grep "<key>UserName</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nh-clean.plist)
  '';
}
