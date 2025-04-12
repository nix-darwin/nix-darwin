{ config, lib, pkgs, ... }:

with lib;

let
  skhd = pkgs.runCommand "skhd-0.0.0" {} "mkdir $out";
in

{
  system.primaryUser = "test-skhd-user";

  services.skhd.enable = true;
  services.skhd.package = skhd;
  services.skhd.skhdConfig = "alt + shift - r  :  chunkc quit";

  test = ''
    echo >&2 "checking skhd service in ~/Library/LaunchAgents"
    grep "org.nixos.skhd" ${config.out}/user/Library/LaunchAgents/org.nixos.skhd.plist
    grep "${skhd}/bin/skhd" ${config.out}/user/Library/LaunchAgents/org.nixos.skhd.plist

    echo >&2 "checking config in /etc/skhdrc"
    grep "alt + shift - r  :  chunkc quit" ${config.out}/etc/skhdrc
  '';
}
