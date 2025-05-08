{ config, pkgs, ... }:

{
  system.primaryUser = "test-launchd-user";

  launchd.daemons.foo.command = "foo";
  launchd.agents.bar.command = "bar";
  launchd.user.agents.baz.command = "baz";

  test = ''
    echo "checking launchd load in /activate" >&2
    grep "launchctl load .* '/Library/LaunchDaemons/org.nixos.foo.plist" ${config.out}/activate
    grep "launchctl load .* '/Library/LaunchAgents/org.nixos.bar.plist" ${config.out}/activate
    echo "checking launchd user agent load in /activate" >&2
    grep "sudo --user=test-launchd-user -- launchctl load .* ~test-launchd-user/Library/LaunchAgents/org.nixos.baz.plist" ${config.out}/activate
    echo "checking LaunchAgents creation /activate" >&2
    grep "sudo --user=test-launchd-user -- mkdir -p ~test-launchd-user/Library/LaunchAgents" ${config.out}/activate
  '';
}
