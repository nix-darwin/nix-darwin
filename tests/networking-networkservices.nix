{ config, lib, ... }:

{
  networking.knownNetworkServices = [
    "Wi-Fi"
    "Thunderbolt Ethernet"
  ];
  networking.dns = [
    "8.8.8.8"
    "8.8.4.4"
  ];
  networking.location."Home Lab" = {
    search = [ "home.lab" ];
  };

  test = ''
    echo checking dns settings in /activate >&2

    grep "networksetup -switchtolocation ${lib.escapeShellArg "Automatic"}" ${config.out}/activate
    grep "networksetup -setdnsservers ${lib.escapeShellArgs [ "Wi-Fi" "8.8.8.8" "8.8.4.4" ]}" ${config.out}/activate
    grep "networksetup -setdnsservers ${lib.escapeShellArgs [ "Thunderbolt Ethernet" "8.8.8.8" "8.8.4.4" ]}" ${config.out}/activate

    grep "networksetup -switchtolocation ${lib.escapeShellArg "Home Lab"}" ${config.out}/activate
    grep "networksetup -setdnsservers ${lib.escapeShellArgs [ "Wi-Fi" "empty" ]}" ${config.out}/activate
    grep "networksetup -setdnsservers ${lib.escapeShellArgs [ "Thunderbolt Ethernet" "empty" ]}" ${config.out}/activate

    echo checking searchdomain settings in /activate >&2

    grep "networksetup -setsearchdomains ${lib.escapeShellArgs [ "Wi-Fi" "empty" ]}" ${config.out}/activate
    grep "networksetup -setsearchdomains ${lib.escapeShellArgs [ "Thunderbolt Ethernet" "empty" ]}" ${config.out}/activate

    grep "networksetup -setsearchdomains ${lib.escapeShellArgs [ "Wi-Fi" "home.lab" ]}" ${config.out}/activate
    grep "networksetup -setsearchdomains ${lib.escapeShellArgs [ "Thunderbolt Ethernet" "home.lab" ]}" ${config.out}/activate
  '';
}
