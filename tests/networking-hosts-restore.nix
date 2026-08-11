{ config, ... }:

{
  networking.enableHosts = true;
  # Deliberately no networking.hosts, extraHosts, or hostFiles set
  # (tests the "content is empty / restore" path)

  test = ''
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts
    printf '%s\n' 'unmanaged before' '# BEGIN Nix-managed' 'stale entry' '# END Nix-managed' 'unmanaged after' > "$hostsPath"

    sed -n '/setting up \/etc\/hosts/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"
    bash "$tmpDir/hosts-activate"

    assertLine() {
      if ! grep -Fx "$1" "$hostsPath" >/dev/null; then
        printf 'FAIL: expected hosts line: %s\n' "$1" >&2
        printf '%s\n' 'Actual hosts file:' >&2
        nl -ba "$hostsPath" >&2
        exit 1
      fi
    }
    assertNoLine() {
      if grep -Fx "$1" "$hostsPath" >/dev/null; then
        printf 'FAIL: unexpected hosts line: %s\n' "$1" >&2
        printf '%s\n' 'Actual hosts file:' >&2
        nl -ba "$hostsPath" >&2
        exit 1
      fi
    }
    assertLine 'unmanaged before'
    assertLine 'unmanaged after'
    assertNoLine 'stale entry'

    printf '%s\n' 'unmanaged before' '# BEGIN Nix-managed' 'unfinished entry' 'unmanaged after' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    assertLine 'unmanaged before'
    assertLine '# BEGIN Nix-managed'
    assertLine 'unfinished entry'
    assertLine 'unmanaged after'
  '';
}
