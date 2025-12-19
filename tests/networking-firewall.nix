{ config, ... }:
{
  networking.applicationFirewall = {
    enable = true;
    blockAllIncoming = true;
    allowSignedApp = false;
    enableStealthMode = null;
  };

  test = ''
    echo "checking socketfilterfw calls in /activate" >&2
    grep "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on" ${config.out}/activate
    grep "/usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on" ${config.out}/activate
    grep "/usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp off" ${config.out}/activate
    (! grep "/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode" ${config.out}/activate)
  '';
}
