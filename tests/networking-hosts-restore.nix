{ config, ... }:

{
  networking.enableHosts = true;
  # Deliberately no networking.hosts, extraHosts, or hostFiles set
  # (tests the "content is empty / restore" path)

  test = ''
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts

    sed -n '/^generateHosts() {/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"

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

    printf '%s\n' 'unmanaged before' '# BEGIN Nix-managed' 'stale entry' '# END Nix-managed' 'unmanaged after' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    assertLine 'unmanaged before'
    assertLine 'unmanaged after'
    assertNoLine 'stale entry'
    assertNoLine '# BEGIN Nix-managed'

    # Several stale blocks are all removed.
    printf '%s\n' 'a' '# BEGIN Nix-managed' 'x' '# END Nix-managed' 'b' '# BEGIN Nix-managed' 'y' '# END Nix-managed' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    assertLine 'a'
    assertLine 'b'
    assertNoLine 'x'
    assertNoLine 'y'

    printf '%s\n' 'unmanaged before' '# BEGIN Nix-managed' 'unfinished entry' 'unmanaged after' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    assertLine 'unmanaged before'
    assertLine '# BEGIN Nix-managed'
    assertLine 'unfinished entry'
    assertLine 'unmanaged after'

    printf '%s\n' 'unmanaged before' '# END Nix-managed' 'unmanaged after' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    assertLine 'unmanaged before'
    assertLine '# END Nix-managed'
    assertLine 'unmanaged after'

    # A file with no managed block must be left completely untouched.
    printf '%s\n' 'only unmanaged' > "$hostsPath"
    inodeBefore=$(ls -i "$hostsPath" | cut -d' ' -f1)
    bash "$tmpDir/hosts-activate"
    inodeAfter=$(ls -i "$hostsPath" | cut -d' ' -f1)
    assertLine 'only unmanaged'
    if [[ "$inodeBefore" != "$inodeAfter" ]]; then
      printf 'FAIL: unmanaged hosts file was rewritten\n' >&2
      exit 1
    fi
  '';
}
