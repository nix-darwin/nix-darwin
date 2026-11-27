{ config, ... }:

# Tests migrating from a /etc/hosts that is a symlink into the Nix store,
# as created by environment.etc."hosts" or the reverted symlink-based
# implementation: it must become a regular file, leaving the store untouched.

{
  networking.enableHosts = true;
  networking.hosts."192.168.1.1" = [ "myhost.local" ];

  test = ''
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts
    storeHosts=$tmpDir/store-hosts
    printf '%s\n' '127.0.0.1 localhost' 'from the store' > "$storeHosts"
    cp "$storeHosts" "$tmpDir/store-hosts.before"
    chmod 0444 "$storeHosts"
    ln -s "$storeHosts" "$hostsPath"

    sed -n '/^generateHosts() {/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"
    bash "$tmpDir/hosts-activate"

    if [[ -L "$hostsPath" ]]; then
      printf 'FAIL: expected /etc/hosts to become a regular file\n' >&2
      exit 1
    fi
    if ! cmp -s "$storeHosts" "$tmpDir/store-hosts.before"; then
      printf 'FAIL: the symlink target was modified\n' >&2
      exit 1
    fi
    for line in 'from the store' '192.168.1.1 myhost.local' '# BEGIN Nix-managed' '# END Nix-managed'; do
      if ! grep -Fx "$line" "$hostsPath" >/dev/null; then
        printf 'FAIL: expected hosts line: %s\n' "$line" >&2
        nl -ba "$hostsPath" >&2
        exit 1
      fi
    done
  '';
}
