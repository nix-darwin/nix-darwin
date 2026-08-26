{
  config,
  ...
}:

{
  services.ntpd-rs.enable = true;

  test = ''
    echo >&2 "checking ntpd-rs service in ~/Library/LaunchDaemons"
    grep "org.nixos.ntpd-rs" ${config.out}/Library/LaunchDaemons/org.nixos.ntpd-rs.plist
  '';
}
