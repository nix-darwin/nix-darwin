{ config, pkgs, ... }:

{
  system.primaryUser = "test-launchd-user";

  launchd.daemons.foo.command = "foo";
  launchd.agents.bar.command = "bar";
  launchd.user.agents.baz.command = "baz";

  launchd.daemons.qux = {
    command = "qux";
    serviceConfig.Disabled = true;
  };
  launchd.user.agents.quux = {
    command = "quux";
    serviceConfig.Disabled = true;
  };

  test = ''
    echo "checking launchd load in /activate" >&2
    grep "launchctl load .* '/Library/LaunchDaemons/org.nixos.foo.plist" ${config.out}/activate
    grep "launchctl load .* '/Library/LaunchAgents/org.nixos.bar.plist" ${config.out}/activate
    echo "checking launchd user agent load in /activate" >&2
    grep "sudo --user=test-launchd-user -- launchctl load .* ~test-launchd-user/Library/LaunchAgents/org.nixos.baz.plist" ${config.out}/activate
    echo "checking LaunchAgents creation /activate" >&2
    grep "sudo --user=test-launchd-user -- mkdir -p ~test-launchd-user/Library/LaunchAgents" ${config.out}/activate

    echo "checking disabled services are loaded only when not disabled in /activate" >&2
    grep -B1 "launchctl load -w '/Library/LaunchDaemons/org.nixos.qux.plist'" ${config.out}/activate \
      | grep "if ! \[\[ .*plutil -extract Disabled raw .*'/Library/LaunchDaemons/org.nixos.qux.plist'"
    grep -B1 "launchctl load -w ~test-launchd-user/Library/LaunchAgents/org.nixos.quux.plist" ${config.out}/activate \
      | grep "if ! \[\[ .*plutil -extract Disabled raw .*~test-launchd-user/Library/LaunchAgents/org.nixos.quux.plist"
    echo "checking disabled services are disabled in /activate" >&2
    grep "launchctl disable system/.*'/Library/LaunchDaemons/org.nixos.qux.plist'" ${config.out}/activate
    grep "launchctl disable \"gui/.*~test-launchd-user/Library/LaunchAgents/org.nixos.quux.plist" ${config.out}/activate
  '';
}
