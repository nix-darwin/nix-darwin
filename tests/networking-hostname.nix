{ lib, config, ... }:

{
  networking.hostName = "EVE";
  networking.computerName = "EVE’s MacBook Pro";

  test = ''
    echo checking hostname in /activate >&2
    grep "scutil --set ComputerName 'EVE’s MacBook Pro'" ${config.out}/activate
    grep "scutil --set LocalHostName ${lib.escapeShellArg "EVE"}" ${config.out}/activate
    grep "scutil --set HostName ${lib.escapeShellArg "EVE"}" ${config.out}/activate
  '';
}
