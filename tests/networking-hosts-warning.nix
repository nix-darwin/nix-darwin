{ config, lib, ... }:

# Tests that networking.hosts and friends being set while
# networking.enableHosts is false is reported, since they would otherwise
# be silently ignored.

{
  networking.hosts."192.168.1.1" = [ "myhost.local" ];

  test = ''
    ${lib.optionalString (!(lib.any (lib.hasInfix "networking.enableHosts") config.warnings)) ''
      printf 'FAIL: expected a warning about networking.enableHosts being disabled\n' >&2
      exit 1
    ''}
  '';
}
