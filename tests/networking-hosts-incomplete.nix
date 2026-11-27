{ config, pkgs, ... }:

# Tests that unterminated or stray Nix-managed markers are treated as user
# content and survive repeated activations, now that a generated block is
# appended after them.

{
  networking.enableHosts = true;
  networking.hosts."192.168.1.1" = [ "myhost.local" ];
  networking.hostFiles = [ (pkgs.writeText "blocklist" "0.0.0.0 ads.example.com\n") ];

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
    assertCount() {
      count=$(grep -Fxc "$1" "$hostsPath" || true)
      if [[ "$count" != "$2" ]]; then
        printf 'FAIL: expected %s occurrence(s) of %s, got %s\n' "$2" "$1" "$count" >&2
        printf '%s\n' 'Actual hosts file:' >&2
        nl -ba "$hostsPath" >&2
        exit 1
      fi
    }

    # A BEGIN without END must not swallow the lines after it, however often
    # activation runs.
    printf '%s\n' 'unmanaged before' '# BEGIN Nix-managed' 'unfinished entry' 'unmanaged after' > "$hostsPath"
    for run in 1 2 3; do
      bash "$tmpDir/hosts-activate"
      assertLine 'unmanaged before'
      assertLine 'unfinished entry'
      assertLine 'unmanaged after'
      assertLine '192.168.1.1 myhost.local'
      assertLine '0.0.0.0 ads.example.com'
      assertCount '# BEGIN Nix-managed' 2
      assertCount '# END Nix-managed' 1
    done

    # A stray END is ordinary content.
    printf '%s\n' 'unmanaged before' '# END Nix-managed' 'unmanaged after' > "$hostsPath"
    for run in 1 2; do
      bash "$tmpDir/hosts-activate"
      assertLine 'unmanaged before'
      assertLine 'unmanaged after'
      assertCount '# END Nix-managed' 2
      assertCount '# BEGIN Nix-managed' 1
    done

    # A last line without a trailing newline must not fuse with the block.
    printf 'no trailing newline' > "$hostsPath"
    bash "$tmpDir/hosts-activate"
    assertLine 'no trailing newline'
    assertLine '# BEGIN Nix-managed'

    # A missing /etc/hosts is created.
    rm "$hostsPath"
    bash "$tmpDir/hosts-activate"
    assertLine '192.168.1.1 myhost.local'
    if [[ "$(stat -c %a "$hostsPath" 2>/dev/null || stat -f %Lp "$hostsPath")" != 644 ]]; then
      printf 'FAIL: expected hosts file mode 644\n' >&2
      exit 1
    fi
  '';
}
