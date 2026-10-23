{ config, ... }: {
  system.primaryUser = "test-launchd-user";

  test = ''
    echo "checking launchd cleanup is present in /activate" >&2
    grep 'rm -f "/Library/LaunchAgents/$f"' ${config.out}/activate
    echo "checking launchd user agent cleanup is present in /activate" >&2
    grep 'sudo --user=test-launchd-user -- rm -f ~test-launchd-user/Library/LaunchAgents/"$f"' ${config.out}/activate
  '';
}
