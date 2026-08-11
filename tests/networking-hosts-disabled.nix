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
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts
    printf '%s\n' '# BEGIN Nix-managed' 'stale entry' '# END Nix-managed' > "$hostsPath"

    sed -n '/setting up \/etc\/hosts/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"
    bash "$tmpDir/hosts-activate"

    if [[ -s "$hostsPath" ]]; then
      printf 'FAIL: expected stale managed hosts file to be empty\n' >&2
      printf '%s\n' 'Actual hosts file:' >&2
      nl -ba "$hostsPath" >&2
      exit 1
    fi
  '';
}
