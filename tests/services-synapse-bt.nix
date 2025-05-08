{ config, lib, pkgs, ... }:

with lib;

let
  synapse-bt = pkgs.runCommand "synapse-bt-0.0.0" {} "mkdir $out";
in

{
  system.primaryUser = "test-synapse-bt-user";

  services.synapse-bt.enable = true;
  services.synapse-bt.package = synapse-bt;

  test = ''
    echo >&2 "checking synapse-bt service in ~/Library/LaunchAgents"
    grep "org.nixos.synapse-bt" ${config.out}/user/Library/LaunchAgents/org.nixos.synapse-bt.plist
    grep "${synapse-bt}/bin/synapse" ${config.out}/user/Library/LaunchAgents/org.nixos.synapse-bt.plist
  '';
}
