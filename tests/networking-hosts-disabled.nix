{ config, ... }:

# Tests that when networking.enableHosts = false, the activation script
# still runs (cleanup) but does NOT write any Nix-managed content,
# even if networking.hosts, extraHosts, or hostFiles are populated.
# This ensures no stale Nix block is left when disabling the feature, while
# anything else is left alone: a missing /etc/hosts is not created and a
# symlinked one is not replaced.

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

    sed -n '/^generateHosts() {/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"

    # A stale block that is the whole file leaves an empty file.
    printf '%s\n' '# BEGIN Nix-managed' 'stale entry' '# END Nix-managed' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    if [[ -s "$hostsPath" ]]; then
      printf 'FAIL: expected stale managed hosts file to be empty\n' >&2
      printf '%s\n' 'Actual hosts file:' >&2
      nl -ba "$hostsPath" >&2
      exit 1
    fi

    # Entries around a stale block survive, and the options stay ignored.
    printf '%s\n' 'unmanaged before' '# BEGIN Nix-managed' 'stale entry' '# END Nix-managed' 'unmanaged after' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    printf '%s\n' 'unmanaged before' 'unmanaged after' > "$tmpDir/expected"
    if ! cmp -s "$hostsPath" "$tmpDir/expected"; then
      printf 'FAIL: expected only the unmanaged lines to remain\n' >&2
      nl -ba "$hostsPath" >&2
      exit 1
    fi

    # Without /etc/hosts there is nothing to clean up, and none is created.
    rm -f "$hostsPath"
    bash "$tmpDir/hosts-activate"
    if [[ -e "$hostsPath" ]]; then
      printf 'FAIL: expected a missing /etc/hosts to stay missing\n' >&2
      exit 1
    fi
    if [[ "$(ls -A "$tmpDir" | grep -c '^hosts\.nix\.')" != 0 ]]; then
      printf 'FAIL: temporary files left behind\n' >&2
      ls -A "$tmpDir" >&2
      exit 1
    fi

    # A /etc/hosts provided another way, e.g. environment.etc."hosts", is a
    # symlink into the store and must stay one.
    printf '%s\n' '127.0.0.1 localhost' > "$tmpDir/store-hosts"
    rm -f "$hostsPath"
    ln -s "$tmpDir/store-hosts" "$hostsPath"
    bash "$tmpDir/hosts-activate"
    if [[ ! -L "$hostsPath" ]]; then
      printf 'FAIL: expected /etc/hosts symlink to be left alone\n' >&2
      exit 1
    fi
    if [[ "$(ls -A "$tmpDir" | grep -c '^hosts\.nix\.')" != 0 ]]; then
      printf 'FAIL: temporary files left behind\n' >&2
      exit 1
    fi
  '';
}
