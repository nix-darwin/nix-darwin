{ config, lib, ... }:

{
  networking.knownNetworkServices = [ "Wi-Fi" "Thunderbolt Ethernet" ];
  networking.dns = [ "8.8.8.8" "8.8.4.4" ];
  networking.dhcpClientId = "test-client-id";

  test = ''
    echo checking dns settings in /activate >&2
    grep "networksetup -setdnsservers ${lib.escapeShellArgs [ "Wi-Fi" "8.8.8.8" "8.8.4.4" ]}" ${config.out}/activate
    grep "networksetup -setdnsservers ${lib.escapeShellArgs [ "Thunderbolt Ethernet" "8.8.8.8" "8.8.4.4" ]}" ${config.out}/activate
    grep "networksetup -setdhcp ${lib.escapeShellArgs [ "Wi-Fi" "test-client-id" ]}" ${config.out}/activate
    grep "networksetup -setdhcp ${lib.escapeShellArgs [ "Thunderbolt Ethernet" "test-client-id" ]}" ${config.out}/activate
    echo checking empty searchdomain settings in /activate >&2
    grep "networksetup -setsearchdomains ${lib.escapeShellArgs [ "Wi-Fi" "empty" ]}" ${config.out}/activate
    grep "networksetup -setsearchdomains ${lib.escapeShellArgs [ "Thunderbolt Ethernet" "empty" ]}" ${config.out}/activate
  '';
}
