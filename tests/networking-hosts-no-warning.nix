{ config, lib, ... }:

# Tests that no warning is emitted when networking.enableHosts is true, or
# when nothing is set that would be ignored.

{
  networking.enableHosts = true;
  networking.hosts."192.168.1.1" = [ "myhost.local" ];

  test = ''
    ${lib.optionalString (lib.any (lib.hasInfix "networking.enableHosts") config.warnings) ''
      printf 'FAIL: unexpected warning about networking.enableHosts\n' >&2
      exit 1
    ''}
  '';
}
