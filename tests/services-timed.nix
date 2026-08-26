{
  config,
  ...
}:

{
  services.timed.enable = true;
  networking.timeServers = [
    "0.nixos.pool.ntp.org"
    "1.nixos.pool.ntp.org"
  ];

  test = ''
    echo checking timed settings in /activate >&2
    grep "systemsetup -setUsingNetworkTime 'on'" ${config.out}/activate
    grep "systemsetup -setNetworkTimeServer '0.nixos.pool.ntp.org"$'\n'"server 1.nixos.pool.ntp.org'" ${config.out}/activate
  '';
}
