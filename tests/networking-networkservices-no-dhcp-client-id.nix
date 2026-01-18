{ config, lib, ... }:

{
  networking.knownNetworkServices = [ "Wi-Fi" "Thunderbolt Ethernet" ];
  networking.dns = [ "8.8.8.8" "8.8.4.4" ];

  test = ''
    echo checking dhcp client ID is not configured in /activate >&2
    if grep -q "networksetup -setdhcp" ${config.out}/activate; then
      echo "unexpected dhcp client ID configuration in /activate" >&2
      exit 1
    fi
  '';
}
