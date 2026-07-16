{ config, ... }:

# Tests that when networking.enableHosts = false, the activation script
# still runs (cleanup) but does NOT write any Nix-managed content,
# even if networking.hosts, extraHosts, or hostFiles are populated.
# This ensures no stale Nix block is left when disabling the feature.

{
  networking.enableHosts = false;
  networking.hosts = {
    "192.168.1.1" = [ "should-not-appear.local" ];
  };
  networking.extraHosts = ''
    172.16.0.1 should-not-appear-either
  '';

  test = ''
    echo "checking activation script is present (cleanup always runs)" >&2
    grep "setting up /etc/hosts" ${config.out}/activate

    echo "checking sed stripping logic is present" >&2
    grep -F "sed '/^# BEGIN Nix-managed\$/,/^# END Nix-managed\$/d'" ${config.out}/activate

    echo "checking no Nix-managed markers despite content being set" >&2
    if grep -F "printf '# BEGIN Nix-managed\n'" ${config.out}/activate; then
      echo "FAIL: Nix-managed block written despite enableHosts=false" >&2
      exit 1
    fi
    if grep -F "printf '# END Nix-managed\n'" ${config.out}/activate; then
      echo "FAIL: Nix-managed END marker despite enableHosts=false" >&2
      exit 1
    fi

    echo "checking hosts content NOT referenced in activation script" >&2
    if grep "should-not-appear" ${config.out}/activate 2>/dev/null; then
      echo "FAIL: hosts content referenced despite enableHosts=false" >&2
      exit 1
    fi

    echo "checking restore path writes original back" >&2
    grep "hostsOriginal.*> /etc/hosts" ${config.out}/activate

    echo "ok: enableHosts=false path verified" >&2
  '';
}
