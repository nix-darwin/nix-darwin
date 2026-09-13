{ config, pkgs, ... }:

{
  system.primaryUser = "test-launchd-user";

  launchd.user.envVariables.FOO = "42";
  system.defaults.dock.autohide = true;

  test = ''
    echo checking launchd user setenv happens before the Dock restart in /activate >&2
    setenv=$(grep -n "launchctl setenv FOO '42'" ${config.out}/activate | cut -d: -f1)
    dock=$(grep -n "restarting Dock" ${config.out}/activate | cut -d: -f1)
    test -n "$setenv"
    test -n "$dock"
    test "$setenv" -lt "$dock"
  '';
}
