{ config, lib, ... }:

{
  networking.firewall.enable = true;
  networking.firewall.stealthmode = true;
  networking.firewall.pf.enable = true;
  networking.firewall.pf.rules = ''
    pass quick on lo0 no state
  '';

  test = ''
    echo "checking firewall enablement in /activate" >&2
    grep "/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on" ${config.out}/activate
    grep "/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on" ${config.out}/activate

    echo "checking pf service in /Library/LaunchDaemons" >&2
    /usr/bin/plutil -extract ProgramArguments raw -expect array \
      ${config.out}/Library/LaunchDaemons/org.nixos.pf.plist | grep "3"
    /usr/bin/plutil -extract ProgramArguments.0 raw -expect string \
      ${config.out}/Library/LaunchDaemons/org.nixos.pf.plist | grep "/bin/sh"
    /usr/bin/plutil -extract ProgramArguments.1 raw -expect string \
      ${config.out}/Library/LaunchDaemons/org.nixos.pf.plist | grep "\-c"
    /usr/bin/plutil -extract ProgramArguments.2 raw -expect string \
      ${config.out}/Library/LaunchDaemons/org.nixos.pf.plist | grep \
      "/bin/wait4path /nix/store && exec /sbin/pfctl -e -a com.apple/nix -f /nix/store/"
    /usr/bin/plutil -extract RunAtLoad raw -expect bool \
      ${config.out}/Library/LaunchDaemons/org.nixos.pf.plist | grep "true"

    anchor=$(/usr/bin/plutil -extract ProgramArguments.2 raw -expect string \
             ${config.out}/Library/LaunchDaemons/org.nixos.pf.plist | awk '{print $10}')
    echo "checking pf rules in $anchor" >&2
    grep "pass quick on lo0 no state" "$anchor"
  '';
}
