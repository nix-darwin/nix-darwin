{ config, lib, pkgs, ... }:

with lib;

let
  synergy = pkgs.runCommand "synergy-0.0.0" {} "mkdir $out";
in

{
  system.primaryUser = "test-synergy-user";

  services.synergy.package = synergy;

  services.synergy.client.enable = true;
  services.synergy.client.screenName = "client_screenName";
  services.synergy.client.serverAddress = "123.123.123.123:123";

  services.synergy.server.enable = true;
  services.synergy.server.configFile = "/tmp/synergy.conf";
  services.synergy.server.screenName = "server_screenName";
  services.synergy.server.address = "0.0.0.0:123";

  test = ''
    echo >&2 "checking synergy-client service in ~/Library/LaunchAgents"
    grep "org.nixos.synergy-client" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-client.plist
    grep "${synergy}/bin/synergyc" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-client.plist
    grep "${config.services.synergy.client.screenName}" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-client.plist
    grep "${config.services.synergy.client.serverAddress}" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-client.plist

    echo >&2 "checking synergy-server service in ~/Library/LaunchAgents"
    grep "org.nixos.synergy-server" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-server.plist
    grep "${synergy}/bin/synergys" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-server.plist
    grep "${config.services.synergy.server.configFile}" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-server.plist
    grep "${config.services.synergy.server.screenName}" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-server.plist
    grep "${config.services.synergy.server.address}" ${config.out}/user/Library/LaunchAgents/org.nixos.synergy-server.plist
  '';
}
